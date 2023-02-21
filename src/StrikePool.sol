// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IAuctionManager.sol";
import "./interfaces/IStrikeController.sol";
import "./libraries/IOptionPricing.sol";
import "./mocks/IMockOracle.sol";

/// @notice Strike vault contract - NFT Option Protocol
/// @author Rems0

contract StrikePool is Ownable, ERC721Holder {
    /*** Constants ***/
    address public erc721;
    address public erc20;
    address public strikeController;
    address public auctionManager;
    bool public liquidationInterrupted = false;
    uint256 immutable epochduration = 14 days;
    uint256 immutable interval = 1 days;
    uint256 immutable firstBidRatio = 800;
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
        address _writer,
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
        uint256 premium;
        uint256 epoch;
        bool covered;
        bool liquidated;
    }

    constructor(address _erc721, address _erc20, address _auctionManager) {
        hatching = block.timestamp;
        erc721 = _erc721;
        erc20 = _erc20;
        strikeController = msg.sender;
        auctionManager = _auctionManager;
        IERC721(erc721).setApprovalForAll(_auctionManager, true);
    }

    /*** Stakers functions ***/

    function stake(uint256 _tokenId, uint256 _strikePrice) public {
        uint256 epoch = getEpoch_2e() + 1;
        require(strikePriceAt[epoch][_strikePrice], "Wrong strikePrice");
        // Transfer the NFT to the pool and write the option
        IERC721(erc721).safeTransferFrom(msg.sender, address(this), _tokenId);
        optionAt[_tokenId].sPrice = _strikePrice;
        optionAt[_tokenId].writer = msg.sender;
        optionAt[_tokenId].epoch = epoch;
        optionAt[_tokenId].buyer = address(0);
        // Push the tokenId into a list for the epoch and increment shares of writer for the epoch
        NFTsAt[epoch][_strikePrice].push(_tokenId);
        ++shareAtOf[epoch][_strikePrice][msg.sender];
        emit Stake(epoch, _tokenId, _strikePrice, msg.sender);
    }

    function restake(uint256 _tokenId, uint256 _strikePrice) public {
        Option memory option = optionAt[_tokenId];
        uint256 epoch = getEpoch_2e() + 1;
        require(
            block.timestamp - hatching >
                option.epoch * epochduration - 2 * interval,
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
        require(strikePriceAt[epoch][_strikePrice], "Wrong strikePrice");
        // Claim premiums if user has some to request
        if (shareAtOf[option.epoch][option.sPrice][msg.sender] > 0) {
            _claimPremiums(option.epoch, option.sPrice, msg.sender);
        }
        // Re-write the option
        optionAt[_tokenId].sPrice = _strikePrice;
        optionAt[_tokenId].epoch = epoch;
        optionAt[_tokenId].buyer = address(0);
        NFTsAt[epoch][_strikePrice].push(_tokenId);
        ++shareAtOf[epoch][_strikePrice][msg.sender];
        emit ReStake(epoch, _tokenId, _strikePrice, msg.sender);
    }

    function claimPremiums(uint256 _epoch, uint256 _strikePrice) public {
        require(
            block.timestamp >
                hatching + (_epoch + 1) * epochduration - 2 * interval,
            "Option didn't expired yet"
        );
        //require(floorPriceAt[_epoch] != 0, "Option didn't expired yet");
        uint256 shares = shareAtOf[_epoch][_strikePrice][msg.sender];
        uint256 totalPremiums = premiumAt[_epoch][_strikePrice];
        uint256 userPremiums = (totalPremiums * shares) /
            NFTsAt[_epoch][_strikePrice].length;
        shareAtOf[_epoch][_strikePrice][msg.sender] = 0;
        IERC20(erc20).transfer(msg.sender, userPremiums);
    }

    function _claimPremiums(
        uint256 _epoch,
        uint256 _strikePrice,
        address _user
    ) internal {
        require(
            block.timestamp >
                hatching + (_epoch + 1) * epochduration - 2 * interval,
            "Option didn't expired yet"
        );
        //require(floorPriceAt[_epoch] != 0, "Option didn't expired yet");
        uint256 shares = shareAtOf[_epoch][_strikePrice][_user];
        uint256 totalPremiums = premiumAt[_epoch][_strikePrice];
        uint256 userPremiums = (totalPremiums * shares) /
            NFTsAt[_epoch][_strikePrice].length;
        shareAtOf[_epoch][_strikePrice][_user] = 0;
        IERC20(erc20).transfer(_user, userPremiums);
    }

    function coverPosition(uint256 _tokenId) public {
        Option memory option = optionAt[_tokenId];
        require(
            floorPriceAt[option.epoch] > 0,
            "Floor price not settled for this epoch"
        );
        require(
            block.timestamp - hatching >
                (option.epoch + 1) * epochduration - 2 * interval,
            "Option has not expired"
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
        require(IERC20(erc20).transferFrom(msg.sender, option.buyer, debt));
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
        // Claim premiums if user has some to request
        if (shareAtOf[option.epoch][option.sPrice][msg.sender] > 0) {
            _claimPremiums(option.epoch, option.sPrice, msg.sender);
        }
        // Transfer back NFT to owner
        IERC721(erc721).safeTransferFrom(address(this), msg.sender, _tokenId);
    }

    /*** Buyers functions ***/

    function buyOption(uint256 _strikePrice) public {
        uint256 epoch = getEpoch_2e();
        require(strikePriceAt[epoch][_strikePrice], "Wrong strikePrice");
        require(
            NFTtradedAt[epoch][_strikePrice] <
                NFTsAt[epoch][_strikePrice].length,
            "All options have been bought"
        );
        require(
            block.timestamp <
                hatching + (getEpoch_2e() + 1) * epochduration - 2 * interval,
            "Option didn't expired yet"
        );
        //require(floorPriceAt[epoch] == 0, "Option expired");

        // Get floor price and volatility
        (uint256 volatility, uint256 floorPrice) = IMockOracle(
            IStrikeController(strikeController).getVolatilityOracle()
        ).getVolatilityAndFloorPrice(erc721);

        uint256 optionPrice = IOptionPricing(
            IStrikeController(strikeController).getOptionPricing()
        ).getOptionPrice(
                false,
                hatching + (epoch + 1) * epochduration,
                _strikePrice,
                floorPrice,
                volatility
            );

        require(
            IERC20(erc20).transferFrom(msg.sender, address(this), optionPrice)
        );
        uint256 tokenIterator = NFTsAt[epoch][_strikePrice].length -
            NFTtradedAt[epoch][_strikePrice] -
            1;
        ++NFTtradedAt[epoch][_strikePrice];
        premiumAt[epoch][_strikePrice] += optionPrice;
        uint256 tokenId = NFTsAt[epoch][_strikePrice][tokenIterator];
        require(
            optionAt[tokenId].buyer == address(0),
            "This option has already been bought"
        );
        optionAt[tokenId].buyer = msg.sender;
        emit BuyOption(
            epoch,
            tokenId,
            _strikePrice,
            optionPrice,
            optionAt[tokenId].writer,
            msg.sender
        );
    }

    function buyAtStrike(uint256 _tokenId) public {
        Option memory option = optionAt[_tokenId];
        require(option.buyer == msg.sender, "You don't own this option");
        require(getEpoch_2e() > option.epoch, "Epoch not finished");
        require(!option.covered, "Position covered");
        require(
            IERC20(erc20).transferFrom(
                msg.sender,
                option.writer,
                option.sPrice
            ),
            "Please set allowance"
        );
        require(!option.liquidated, "option already liquidated");
        IERC721(erc721).safeTransferFrom(address(this), msg.sender, _tokenId);
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
        uint256 firstBid = (floorPriceAt[epoch] * firstBidRatio) / 1000;
        IAuctionManager(auctionManager).start(
            erc721,
            _tokenId,
            firstBid,
            option.writer,
            option.buyer,
            debt
        );
        emit LiquidateNFT(
            _tokenId,
            firstBid,
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
    ) public onlyOwner {
        for (uint256 i = 0; i != _strikePrices.length; ++i) {
            strikePriceAt[_epoch][_strikePrices[i]] = true;
        }
        emit SetStrikePrice(_epoch, _strikePrices);
    }

    function setfloorpriceAt(
        uint256 _epoch,
        uint256 _floorPrice
    ) public onlyOwner {
        require(_floorPrice > 0, "Floor price < 0");
        floorPriceAt[_epoch] = _floorPrice;
        emit SetFloorPrice(_epoch, _floorPrice);
    }

    function setAuctionManager(address _auctionManager) public onlyOwner {
        auctionManager = _auctionManager;
    }

    function setLiquidationInterrupted(
        bool _liquidationInterrupted
    ) public onlyOwner {
        liquidationInterrupted = _liquidationInterrupted;
    }

    /*** Getters ***/
    function getfloorprice(uint256 _epoch) public view returns (uint256) {
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
}
