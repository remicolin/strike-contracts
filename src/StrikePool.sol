// SPDX-License-Identifier: unlicensed
pragma solidity 0.8.16;

import "@openzeppelin-up/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin-up/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-up/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin-up/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-up/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/IAuctionManager.sol";
import "./libraries/IOptionPricing.sol";
import "./mocks/IMockOracle.sol";
import {Initializable} from "@openzeppelin-up/contracts/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-up/contracts/access/AccessControlUpgradeable.sol";

/// @notice Strike vault contract - NFT Option Protocol
/// @author Rems0

contract StrikePool is
    ERC721HolderUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /*** Constants ***/
    address public erc721;
    address public erc20;
    address public strikeController;
    address public auctionManager;
    address public optionPricing;
    address public volatilityOracle;

    bytes32 public constant FLOOR_PRICE_PROVIDER_ROLE =
        keccak256("FLOOR_PRICE_PROVIDER_ROLE");

    bool public liquidationInterrupted;
    uint256 immutable epochduration = 14 days;
    uint256 immutable interval = 1 days;
    uint256 public hatching;
    /*** Owner variables ***/
    mapping(uint256 => mapping(uint256 => bool)) strikePriceAt;
    mapping(uint256 => mapping(uint256 => uint256)) premiumAt;
    mapping(uint256 => uint256) floorPriceAt;
    /*** Option relatives variables ***/
    mapping(uint256 => mapping(uint256 => uint256[])) NFTsAt;
    mapping(uint256 => mapping(uint256 => uint256)) NFTtradedAt;
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) shareAtOf;
    mapping(uint256 => Option) optionAt;
    /*** Events ***/
    event Stake(
        uint256 indexed _epoch,
        uint256 _tokenId,
        uint256 _strikePrice,
        address indexed _writer
    );
    event ReStake(
        uint256 indexed _epoch,
        uint256 _tokenId,
        uint256 _strikePrice,
        address indexed _writer
    );
    event BuyOption(
        uint256 indexed _epoch,
        uint256 _tokenId,
        uint256 _strikePrice,
        uint256 _premium,
        address indexed _buyer
    );
    event CoverPosition(
        uint256 indexed _epoch,
        uint256 _tokenId,
        uint256 _debt,
        address indexed _writer,
        address _buyer
    );
    event WithdrawNFT(uint256 _tokenId, address _owner);
    event ClaimPremiums(
        uint256 indexed _epoch,
        uint256 _shares,
        uint256 _premiums,
        address indexed _owner
    );
    event LiquidateNFT(
        uint256 indexed _tokenId,
        uint256 _firstPrice,
        address _writer,
        address _buyer,
        uint256 _debt
    );
    event SetFloorPrice(uint256 indexed _epoch, uint256 _floorPrice);
    event SetStrikePrice(uint256 indexed _epoch, uint256[] _strikePrices);

    struct Option {
        address writer;
        address buyer;
        uint256 sPrice;
        uint256 epoch;
        bool covered;
        bool liquidated;
    }

    /*** Initialize the contract ***/

    function initialize(
        address _erc721,
        address _erc20,
        address _auctionManager,
        address _optionPricing,
        address _volatilityOracle,
        address _admin
    ) public initializer {
        require(_erc721 != address(0), "ERC721 address is 0");
        require(_erc20 != address(0), "ERC20 address is 0");
        require(_auctionManager != address(0), "AuctionManager address is 0");
        require(_optionPricing != address(0), "OptionPricing address is 0");
        require(
            _volatilityOracle != address(0),
            "VolatilityOracle address is 0"
        );
        require(_admin != address(0), "Admin address is 0");
        __ERC721Holder_init();
        __ReentrancyGuard_init();
        __AccessControl_init();
        hatching = block.timestamp;
        erc721 = _erc721;
        erc20 = _erc20;
        strikeController = msg.sender;
        auctionManager = _auctionManager;
        optionPricing = _optionPricing;
        volatilityOracle = _volatilityOracle;
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(FLOOR_PRICE_PROVIDER_ROLE, _admin);
        IERC721Upgradeable(erc721).setApprovalForAll(_auctionManager, true);
    }

    /*** Stakers functions ***/

    function stake(uint256 _tokenId, uint256 _strikePrice) public {
        uint256 nepoch = getEpoch_2e() + 1;
        require(strikePriceAt[nepoch][_strikePrice], "Wrong strikePrice");
        // Transfer the NFT to the pool and write the option
        IERC721Upgradeable(erc721).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );
        optionAt[_tokenId].sPrice = _strikePrice;
        optionAt[_tokenId].writer = msg.sender;
        optionAt[_tokenId].epoch = nepoch;
        optionAt[_tokenId].buyer = address(0);
        // Push the tokenId into a list for the epoch and increment shares of writer for the epoch
        NFTsAt[nepoch][_strikePrice].push(_tokenId);
        ++shareAtOf[nepoch][_strikePrice][msg.sender];
        emit Stake(nepoch, _tokenId, _strikePrice, msg.sender);
    }

    function restake(
        uint256 _tokenId,
        uint256 _strikePrice
    ) public nonReentrant {
        Option memory option = optionAt[_tokenId];
        uint256 nepoch = getEpoch_2e() + 1;
        require(
            block.timestamp >
                hatching + (option.epoch + 1) * epochduration - 2 * interval,
            "Option has not expired"
        );
        require(option.writer == msg.sender, "You are not the owner");
        require(
            floorPriceAt[option.epoch] > 0,
            "Floor price not settled for this epoch"
        );
        require(
            floorPriceAt[option.epoch] <= option.sPrice ||
                option.covered ||
                option.buyer == address(0),
            "Cover your position"
        );
        require(strikePriceAt[nepoch][_strikePrice], "Wrong strikePrice");

        // Re-write the option
        optionAt[_tokenId].epoch = nepoch;
        optionAt[_tokenId].sPrice = _strikePrice;
        optionAt[_tokenId].buyer = address(0);
        NFTsAt[nepoch][_strikePrice].push(_tokenId);
        ++shareAtOf[nepoch][_strikePrice][msg.sender];

        // Claim premiums if user has some to request
        if (shareAtOf[option.epoch][option.sPrice][msg.sender] > 0) {
            _claimPremiums_Cb4(option.epoch, option.sPrice, msg.sender);
        }

        emit ReStake(nepoch, _tokenId, _strikePrice, msg.sender);
    }

    function claimPremiums(uint256 _epoch, uint256 _strikePrice) public {
        require(
            block.timestamp >
                hatching + (_epoch + 1) * epochduration - 2 * interval,
            "Option didn't expired yet"
        );

        _claimPremiums_Cb4(_epoch, _strikePrice, msg.sender);
    }

    function _claimPremiums_Cb4(
        uint256 _epoch,
        uint256 _strikePrice,
        address _user
    ) internal {
        // Compute the number of shares and the premiums to claim
        uint256 shares = shareAtOf[_epoch][_strikePrice][_user];
        shareAtOf[_epoch][_strikePrice][_user] = 0;
        uint256 totalPremiums = premiumAt[_epoch][_strikePrice];
        uint256 userPremiums = (totalPremiums * shares) /
            NFTsAt[_epoch][_strikePrice].length;

        // Transfer the premiums to the user
        IERC20Upgradeable(erc20).transfer(_user, userPremiums);
    }

    function coverPosition(uint256 _tokenId) public {
        Option memory option = optionAt[_tokenId];
        require(
            block.timestamp - hatching >
                (option.epoch + 1) * epochduration - 2 * interval,
            "Option has not expired"
        );
        require(
            floorPriceAt[option.epoch] > 0,
            "Floor price not settled for this epoch"
        );
        require(
            floorPriceAt[option.epoch] > option.sPrice,
            "Option expired worthless"
        );
        require(option.liquidated != true, "Option already liquidated");
        require(option.buyer != address(0), "Option have not been bought");
        require(!option.covered, "Option already covered");
        // Transfer debt to option writer and set the position covered
        uint256 debt = floorPriceAt[option.epoch] - option.sPrice;
        require(
            IERC20Upgradeable(erc20).transferFrom(
                msg.sender,
                option.buyer,
                debt
            )
        );
        optionAt[_tokenId].covered = true;
        emit CoverPosition(
            option.epoch,
            _tokenId,
            debt,
            msg.sender,
            option.buyer
        );
    }

    function withdrawNFT(uint256 _tokenId) public {
        Option memory option = optionAt[_tokenId];
        require(getEpoch_2e() > option.epoch, "Epoch not finished");
        require(
            floorPriceAt[option.epoch] > 0,
            "Floor price not settled for this epoch"
        );
        require(option.writer == msg.sender, "You are not the owner");
        require(
            floorPriceAt[option.epoch] <= option.sPrice ||
                option.covered ||
                option.buyer == address(0),
            "Cover your position"
        );
        // Claim premiums if user has some to request
        if (shareAtOf[option.epoch][option.sPrice][msg.sender] > 0) {
            _claimPremiums_Cb4(option.epoch, option.sPrice, msg.sender);
        }
        // Transfer back NFT to owner
        IERC721Upgradeable(erc721).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );
    }

    /*** Buyers functions ***/

    function buyOptions(
        uint256 _strikePrice,
        uint256 _amount
    ) public nonReentrant {
        uint256 epoch = getEpoch_2e();

        // Check if epoch and strikePrice are correct
        require(strikePriceAt[epoch][_strikePrice], "Wrong strikePrice");
        require(
            block.timestamp <
                hatching + (epoch + 1) * epochduration - 2 * interval,
            "Wait for the next epoch"
        );

        // Check if there are enough tokens available
        uint256 tokensAvailable = NFTsAt[epoch][_strikePrice].length -
            NFTtradedAt[epoch][_strikePrice];
        require(_amount <= tokensAvailable, "Not enough tokens available");

        // Get floor price and volatility and calculate option price
        (uint256 volatility, uint256 floorPrice) = IMockOracle(volatilityOracle)
            .getVolatilityAndFloorPrice(erc721);

        uint256 optionPrice = IOptionPricing(optionPricing).getOptionPrice(
            false,
            hatching + (epoch + 1) * epochduration,
            _strikePrice,
            floorPrice,
            volatility
        );

        // Transfer erc20 to the contract
        require(
            IERC20Upgradeable(erc20).transferFrom(
                msg.sender,
                address(this),
                _amount * optionPrice
            )
        );

        // Update state variables
        uint256 tokenIterator = NFTsAt[epoch][_strikePrice].length -
            NFTtradedAt[epoch][_strikePrice] -
            1;
        NFTtradedAt[epoch][_strikePrice] += _amount;
        premiumAt[epoch][_strikePrice] += _amount * optionPrice;
        for (uint256 i = tokenIterator; i < tokenIterator + _amount; i++) {
            uint256 tokenId = NFTsAt[epoch][_strikePrice][i];
            optionAt[tokenId].buyer = msg.sender;
            emit BuyOption(
                epoch,
                tokenId,
                _strikePrice,
                optionPrice,
                msg.sender
            );
        }
    }

    function buyAtStrike(uint256 _tokenId) public {
        Option memory option = optionAt[_tokenId];
        require(option.buyer == msg.sender, "You don't own this option");
        require(getEpoch_2e() > option.epoch, "Epoch not finished");
        require(!option.covered, "Position covered");
        require(!option.liquidated, "option already liquidated");
        require(
            floorPriceAt[option.epoch] > 0,
            "Floor price not settled for this epoch"
        );

        require(
            IERC20Upgradeable(erc20).transferFrom(
                msg.sender,
                option.writer,
                option.sPrice
            )
        );

        IERC721Upgradeable(erc721).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );
    }

    function liquidateNFT(uint256 _tokenId) public {
        Option memory option = optionAt[_tokenId];
        uint256 epoch = option.epoch;
        require(!liquidationInterrupted);
        require(
            block.timestamp - hatching >
                (option.epoch + 1) * epochduration + interval,
            "Liquidation period isn't reached"
        );
        require(
            floorPriceAt[epoch] > 0,
            "Floor price not settled for this epoch"
        );
        require(
            floorPriceAt[epoch] > option.sPrice,
            "Option expired worthless"
        );
        require(!option.covered, "Position covered");
        require(option.liquidated != true, "Option already liquidated");
        // Set the option to liquidated and start an auction on the NFT
        optionAt[_tokenId].liquidated = true;
        optionAt[_tokenId].writer = address(0);
        uint256 debt = floorPriceAt[epoch] - option.sPrice;
        IAuctionManager(auctionManager).start(
            erc721,
            _tokenId,
            floorPriceAt[epoch],
            option.writer,
            option.buyer,
            debt
        );
        emit LiquidateNFT(
            _tokenId,
            floorPriceAt[epoch],
            option.writer,
            option.buyer,
            debt
        );
    }

    /*** Auction contract ***/

    function bidAuction(uint256 _tokenId, uint256 _amount) public {
        IAuctionManager(auctionManager).bid(
            erc721,
            _tokenId,
            _amount,
            msg.sender
        );
    }

    function endAuction(uint256 _tokenId) public {
        require(
            IAuctionManager(auctionManager).end(erc721, address(this), _tokenId)
        );
        optionAt[_tokenId].liquidated = false;
        optionAt[_tokenId].covered = true;
        optionAt[_tokenId].writer = address(0);
    }

    /*** Admin functions ***/

    function setStrikePriceAt(
        uint256 _epoch,
        uint256[] memory _strikePrices
    ) public onlyProvider {
        for (uint256 i = 0; i != _strikePrices.length; ++i) {
            strikePriceAt[_epoch][_strikePrices[i]] = true;
        }
        emit SetStrikePrice(_epoch, _strikePrices);
    }

    function setfloorpriceAt(
        uint256 _epoch,
        uint256 _floorPrice
    ) public onlyProvider {
        require(_floorPrice > 0, "Floor price < 0");
        floorPriceAt[_epoch] = _floorPrice;
        emit SetFloorPrice(_epoch, _floorPrice);
    }

    function setAuctionManager(address _auctionManager) public onlyAdmin {
        auctionManager = _auctionManager;
    }

    function setOptionPricing(address _optionPricing) public onlyAdmin {
        optionPricing = _optionPricing;
    }

    function setVolatilityOracle(address _volatilityOracle) public onlyAdmin {
        volatilityOracle = _volatilityOracle;
    }

    function setLiquidationInterrupted(
        bool _liquidationInterrupted
    ) public onlyAdmin {
        liquidationInterrupted = _liquidationInterrupted;
    }

    function setFloorPriceProvider(address _provider) public onlyAdmin {
        _grantRole(FLOOR_PRICE_PROVIDER_ROLE, _provider);
    }

    /*** Getters ***/

    function getFloorPrice(uint256 _epoch) public view returns (uint256) {
        return floorPriceAt[_epoch];
    }

    function getEpoch_2e() public view returns (uint256) {
        return (block.timestamp - hatching) / epochduration;
    }

    function getEpochDuration() public pure returns (uint256) {
        return epochduration;
    }

    function getInterval() public pure returns (uint256) {
        return interval;
    }

    function getSharesAtOf(
        uint256 _epoch,
        uint256 _strikePrice,
        address _add
    ) public view returns (uint256) {
        return shareAtOf[_epoch][_strikePrice][_add];
    }

    function getAmountLockedAt(
        uint256 _epoch,
        uint256 _strikePrice
    ) public view returns (uint256) {
        return NFTsAt[_epoch][_strikePrice].length;
    }

    function getOption(
        uint256 _tokenId
    ) public view returns (Option memory option) {
        return optionAt[_tokenId];
    }

    function getOptionAvailableAt(
        uint256 _epoch,
        uint256 _strikePrice
    ) public view returns (uint256) {
        return
            NFTsAt[_epoch][_strikePrice].length -
            NFTtradedAt[_epoch][_strikePrice];
    }

    /*** Modifiers ***/
    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "msg.sender is not admin"
        );
        _;
    }

    modifier onlyProvider() {
        require(
            hasRole(FLOOR_PRICE_PROVIDER_ROLE, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "msg.sender is not floor price provider"
        );
        _;
    }
}
