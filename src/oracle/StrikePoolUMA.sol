// SPDX-License-Identifier: unlicensed
pragma solidity 0.8.16;

import "@uma/core/contracts/optimistic-oracle-v3/interfaces/OptimisticOracleV3Interface.sol";
import "@openzeppelin-up/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin-up/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-up/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin-up/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-up/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interfaces/IAuctionManager.sol";
import "../libraries/IOptionPricing.sol";
import "../mocks/IMockOracle.sol";
import {Initializable} from "@openzeppelin-up/contracts/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-up/contracts/access/AccessControlUpgradeable.sol";

/// @notice Strike vault contract - NFT Option Protocol
/// @author Rems0

contract StrikePoolUMA is
    ERC721HolderUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    /*** Oracle part  ***/
    IERC20 public  defaultCurrency;
    OptimisticOracleV3Interface public oo;
    uint64 public constant assertionLiveness = 7200;
    bytes32 public  defaultIdentifier;

    /*** Constants ***/
    address public erc721;
    address public erc20;
    address public strikeController;
    address public auctionManager;
    address public optionPricing;
    address public volatilityOracle;

    bool public liquidationInterrupted;
    uint256 constant epochduration = 14 days;
    uint256 constant interval = 1 days;
    uint256 public hatching;

    /*** Roles ***/
    bytes32 public constant FLOOR_PRICE_PROVIDER_ROLE =
        keccak256("FLOOR_PRICE_PROVIDER_ROLE");

    /*** Owner variables ***/
    mapping(uint256 => mapping(uint256 => bool)) strikePriceAt;
    mapping(uint256 => mapping(uint256 => uint256)) premiumAt;
    mapping(uint256 => uint256) floorPriceAt;

    /*** Option relatives variables ***/
    mapping(uint256 => mapping(uint256 => uint256[])) NFTsAt;
    mapping(uint256 => mapping(uint256 => uint256)) NFTtradedAt;
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) shareAtOf;
    mapping(uint256 => Option) optionAt;
    /*** Oracle part ***/
    mapping(bytes32 => uint256[]) public assertionsOptions;

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
        address indexed _writer
    );
    event WithdrawNFT(uint256 indexed _tokenId, address indexed _owner);
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
        uint256 premium;
    }

    /*** Initialize the contract ***/

    function initialize(
        address _erc721,
        address _erc20,
        address _auctionManager,
        address _optionPricing,
        address _volatilityOracle,
        address _admin,
        address _defaultCurrency,
        address _oo
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

        /*** Oracle  ***/
        
        defaultCurrency = IERC20(_defaultCurrency);
        oo = OptimisticOracleV3Interface(_oo);
        defaultIdentifier = oo.defaultIdentifier(); 
    }

    /*** Stakers functions ***/

    /* Functions relatives to NFT staking */

    /// @notice Stake NFTs and write option for the next epoch
    /// @param _tokenId Id of the NFT to stake
    /// @param _strikePrice Strike price of the option
    function stakeNFTs(uint256 _tokenId, uint256 _strikePrice) public {
        uint256 nepoch = getEpoch_2e() + 1;
        require(strikePriceAt[nepoch][_strikePrice], "Wrong strikePrice");
        _stakeNFTs_9sJ(nepoch, _tokenId, _strikePrice, msg.sender);

        ++shareAtOf[nepoch][_strikePrice][msg.sender];
    }

    /// @notice Stake NFTs and write options for the next epoch
    /// @param _tokenIds List of Ids of the NFTs to stake
    /// @param _strikePrice Strike price of the option
    function stakeNFTs(
        uint256[] memory _tokenIds,
        uint256 _strikePrice
    ) public {
        uint256 nepoch = getEpoch_2e() + 1;
        require(strikePriceAt[nepoch][_strikePrice], "Wrong strikePrice");
        _tokenIds.length;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            _stakeNFTs_9sJ(nepoch, _tokenIds[i], _strikePrice, msg.sender);
        }
        // Increment shares of writer for the epoch
        shareAtOf[nepoch][_strikePrice][msg.sender] += _tokenIds.length;
    }

    /// @dev Internal function to stake NFTs
    /// @param _tokenId Id of the NFT to stake
    /// @param _strikePrice Strike price of the option
    /// @param _writer Address of the writer
    function _stakeNFTs_9sJ(
        uint256 _nepoch,
        uint256 _tokenId,
        uint256 _strikePrice,
        address _writer
    ) internal {
        // Transfer the NFT to the pool
        IERC721Upgradeable(erc721).safeTransferFrom(
            _writer,
            address(this),
            _tokenId
        );

        // Write the option
        optionAt[_tokenId].sPrice = _strikePrice;
        optionAt[_tokenId].writer = _writer;
        optionAt[_tokenId].epoch = _nepoch;
        optionAt[_tokenId].buyer = address(0);

        NFTsAt[_nepoch][_strikePrice].push(_tokenId);

        emit Stake(_nepoch, _tokenId, _strikePrice, _writer);
    }

    /* Functions relatives to NFT re-staking  */

    /// @notice Restake NFTs and write option for the next epoch
    /// @param _tokenId Id of the NFT to restake
    /// @param _strikePrice Strike price of the option
    function restakeNFTs(
        uint256 _tokenId,
        uint256 _strikePrice
    ) public nonReentrant {
        uint256 nepoch = getEpoch_2e() + 1;

        require(strikePriceAt[nepoch][_strikePrice], "Wrong strikePrice");

        _restakeNFTs_5cC(nepoch, _tokenId, _strikePrice, msg.sender);
        ++shareAtOf[nepoch][_strikePrice][msg.sender];
    }

    /// @notice Restake NFTs and write options for the next epoch
    /// @param _tokenIds List of Ids of the NFTs to restake
    /// @param _strikePrice Strike price of the option
    function restakeNFTs(
        uint256[] calldata _tokenIds,
        uint256 _strikePrice
    ) public nonReentrant {
        uint256 nepoch = getEpoch_2e() + 1;
        require(strikePriceAt[nepoch][_strikePrice], "Wrong strikePrice");

        // boucle sur les tokenIds
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            _restakeNFTs_5cC(nepoch, _tokenIds[i], _strikePrice, msg.sender);
        }
        // Increment shares of writer for the epoch
        // Be sure the transaction don't revertse before or the shares will not be incremented for the next epoch
        shareAtOf[nepoch][_strikePrice][msg.sender] += _tokenIds.length;
    }

    /// @dev Internal function to restake NFTs
    /// @param _tokenId Id of the NFT to restake
    /// @param _strikePrice Strike price of the option
    function _restakeNFTs_5cC(
        uint256 _nepoch,
        uint256 _tokenId,
        uint256 _strikePrice,
        address _writer
    ) internal {
        Option memory option = optionAt[_tokenId];
        require(
            block.timestamp >
                hatching + (option.epoch + 1) * epochduration - 2 * interval,
            "Option has not expired"
        );
        require(option.writer == _writer, "You are not the owner");
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

        // Re-write the option
        optionAt[_tokenId].epoch = _nepoch;
        optionAt[_tokenId].sPrice = _strikePrice;
        optionAt[_tokenId].buyer = address(0);
        optionAt[_tokenId].covered = false;

        // Push the tokenId into a list for the epoch
        // Shares will be incremented after the loop to save gas
        NFTsAt[_nepoch][_strikePrice].push(_tokenId);

        emit ReStake(_nepoch, _tokenId, _strikePrice, _writer);
    }

    /* Functions relatives to premiums claiming  */

    /// @param _epoch Epoch of the option to claim premiums
    /// @param _strikePrice Strike price of the option to claim premiums
    function claimPremiums(uint256 _epoch, uint256 _strikePrice) public {
        require(
            block.timestamp >
                hatching + (_epoch + 1) * epochduration - 2 * interval,
            "Option didn't expired yet"
        );

        _claimPremiums_Cb4(_epoch, _strikePrice, msg.sender);
    }

    /// @dev Internal function to claim premiums
    /// @dev This function will claim all the premiums for a given epoch and strike price
    /// @param _epoch Epoch of the option to claim premiums
    /// @param _strikePrice Strike price of the option to claim premiums
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

    /* Others stakers functions */

    /// @notice When an option expires in the money, the writer can cover his position to avoid liquidation
    /// @param _tokenId Id of the NFT writer needs to cover to avoid liquidation
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
        emit CoverPosition(option.epoch, _tokenId, debt, msg.sender);
    }

    /// @notice Whithdraw an NFT from the protocol
    /// @param _tokenId Id of the NFT to withdraw
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
        // Update state variable
        optionAt[_tokenId].writer = address(0);
        optionAt[_tokenId].covered = false;

        // Transfer back NFT to owner
        IERC721Upgradeable(erc721).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );
    }

    /*** Buyers functions ***/

    /// @notice Buy options of the current epoch for a given strike price
    /// @param _strikePrice Strike price of the options to buy
    /// @param _amount Amount of options to buy
    function buyOptions(
        uint256 _strikePrice,
        uint256 _amount
    ) public nonReentrant returns (bytes32 assertionId) {
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
        uint256 bond = oo.getMinimumBond(address(defaultCurrency));
        defaultCurrency.transferFrom(msg.sender, address(this), bond);
        defaultCurrency.approve(address(oo), bond);
        assertionId = oo.assertTruth(
            abi.encodePacked(
                "Insurance contract is claiming that insurance event "
            ),
            msg.sender,
            address(this),
            address(0), // No sovereign security.
            0,
            defaultCurrency,
            bond,
            defaultIdentifier,
            bytes32(0) // No domain.
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
            NFTtradedAt[epoch][_strikePrice];

        NFTtradedAt[epoch][_strikePrice] += _amount;
        premiumAt[epoch][_strikePrice] += _amount * optionPrice;
        for (uint256 i = tokenIterator; i >= tokenIterator + 1 - _amount; i--) {
            // Use i-1 here to avoid underflow int he for loop
            // Needs to do it because tokenIterator uses array.length
            uint256 tokenId = NFTsAt[epoch][_strikePrice][i - 1];
            assertionsOptions[assertionId].push(tokenId);
            optionAt[tokenId].buyer = msg.sender;
            optionAt[tokenId].premium = optionPrice;
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

        // Transfer erc20 to the option writer
        require(
            IERC20Upgradeable(erc20).transferFrom(
                msg.sender,
                option.writer,
                option.sPrice
            )
        );
        // Update state variables
        optionAt[_tokenId].writer = address(0);

        // Transfer back NFT to the option buyer
        IERC721Upgradeable(erc721).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );
    }

    /// @dev Liquidate a position
    /// @dev When an option expires in the money, the buyer can liquidate the position if the writer didn't cover it on time
    /// @dev The function will use the AuctionManager contract to sell the NFT and the option buyer will receive the debt
    /// @param _tokenId Id of the NFT to liquidate
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

    /*** Auction contract functions ***/

    /// @notice Bid on an auction started by the liquidation of a position
    /// @param _tokenId Id of the NFT to bid on
    /// @param _amount Amount of ERC20 to bid
    function bidAuction(uint256 _tokenId, uint256 _amount) public {
        IAuctionManager(auctionManager).bid(
            erc721,
            _tokenId,
            _amount,
            msg.sender
        );
    }

    /// @notice End an auction started by the liquidation of a position
    /// @param _tokenId Id of the NFT to end the auction on
    function endAuction(uint256 _tokenId) public {
        require(
            IAuctionManager(auctionManager).end(erc721, address(this), _tokenId)
        );
        optionAt[_tokenId].liquidated = false;
        optionAt[_tokenId].covered = true;
        optionAt[_tokenId].writer = address(0);
    }

    /*** Admin functions ***/

    /// @notice Set the strike price for an epoch
    /// @param _epoch Epoch to set the strike price for
    /// @param _strikePrices Array of strike prices to set
    function setStrikePriceAt(
        uint256 _epoch,
        uint256[] memory _strikePrices
    ) public onlyProvider {
        for (uint256 i = 0; i != _strikePrices.length; ++i) {
            strikePriceAt[_epoch][_strikePrices[i]] = true;
        }
        emit SetStrikePrice(_epoch, _strikePrices);
    }

    /// @notice Set the floor price for an epoch
    /// @dev The floor price will be set by the oracle
    /// @param _epoch Epoch to set the floor price for
    /// @param _floorPrice Floor price to set
    function setFloorPriceAt(
        uint256 _epoch,
        uint256 _floorPrice
    ) public onlyProvider {
        require(_floorPrice > 0, "Floor price <= 0");
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

    /*** Oracle functions ***/
    
    // OptimisticOracleV3 resolve callback.
    function assertionResolvedCallback(bytes32 assertionId, bool _validOptionPrice) public {
        require(msg.sender == address(oo));
        if (!_validOptionPrice){
            uint256[] memory optionList = assertionsOptions[assertionId];
            uint256 firstOption = optionList[0];
            require(optionAt[firstOption].epoch == getEpoch_2e(),"You have to shoot corrupted options before expiry");
            for (uint256 i=0 ; i < optionList.length; i++){
                address optionBuyer = optionAt[optionList[i]].buyer;
                require(optionBuyer != address(0),"option buyer is zero address");
                optionAt[optionList[i]].buyer = address(0);
                IERC20Upgradeable(erc20).transfer(payable(optionBuyer),optionAt[optionList[i]].premium);
            }
        }
    }
    
    
    // If assertion is disputed, do nothing and wait for resolution.
    // This OptimisticOracleV3 callback function needs to be defined so the OOv3 doesn't revert when it tries to call it.
    function assertionDisputedCallback(bytes32 assertionId) public {}
    

}
