// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStrikeController.sol";

contract AuctionManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Start(uint256 _nftId, uint256 startingBid);
    event End(address actualBidder, uint256 highestBid);
    event Bid(address indexed sender, uint256 amount);
    event Withdraw(address indexed bidder, uint256 amount);

    IERC20 public erc20;
    address public maincontract;

    uint256 public interval = 1 days / 4;
    uint256 public liquidationRatio = 900;
    uint256 public firstBidRatio = 800;
    uint256 public minBidRatio = 1015;

    struct Auction {
        uint256 highestBid;
        address actualBidder;
        mapping(address => uint256) bids;
        address optionWriter;
        address optionOwner;
        uint256 debt;
        uint256 tlastBid;
        bool isGoing;
    }
    struct AuctionLight {
        uint256 highestBid;
        address actualBidder;
        address optionWriter;
        address optionOwner;
        uint256 debt;
        uint256 tlastBid;
        bool isGoing;
    }

    mapping(address => mapping(uint256 => Auction)) auctions;

    constructor(address _wrappedEtherAddress) {
        erc20 = IERC20(_wrappedEtherAddress);
    }

    function start(
        address _tokenAddress,
        uint256 _nftId,
        uint256 _floorPrice,
        address _optionWriter,
        address _optionOwner,
        uint256 _debt
    ) public nonReentrant {
        Auction storage auction = auctions[_tokenAddress][_nftId];
        require(
            msg.sender ==
                IStrikeController(maincontract).getPoolFromTokenAddress(
                    _tokenAddress
                ),
            "Call this function from pool contract"
        );
        require(!auction.isGoing, "Already started[_nftId]!");
        auction.isGoing = true;
        auction.highestBid = (_floorPrice * firstBidRatio) / 1000;
        auction.actualBidder = address(0);
        auction.tlastBid = block.timestamp;
        auction.optionWriter = _optionWriter;
        auction.optionOwner = _optionOwner;
        auction.debt = _debt;
        emit Start(_nftId, (_floorPrice * firstBidRatio) / 1000);
    }

    function bid(
        address _tokenAddress,
        uint256 _nftId,
        uint256 _bidAmount,
        address _user
    ) external {
        Auction storage auction = auctions[_tokenAddress][_nftId];
        require(auction.isGoing, "Auction didn't started");
        require(
            block.timestamp < auction.tlastBid + interval ||
                auction.actualBidder == address(0),
            "Action ended"
        );
        require(
            _bidAmount + auction.bids[_user] >
                ((auction.highestBid) * minBidRatio) / 1000,
            "The total bid is lower than actual maxBid"
        );
        require(
            erc20.transferFrom(_user, address(this), _bidAmount),
            "ERC20 - transfer is not allowed"
        );
        auction.bids[_user] += _bidAmount;
        auction.highestBid = auction.bids[_user];
        auction.actualBidder = _user;
        auction.tlastBid = block.timestamp;
        emit Bid(auction.actualBidder, auction.highestBid);
    }

    //  Users can retract at any times if they aren't the actual bidder
    function withdraw(
        address _tokenAddress,
        uint256 _nftId,
        address _user
    ) external nonReentrant {
        Auction storage auction = auctions[_tokenAddress][_nftId];
        require(_user != auction.actualBidder, "You are the actual bidder");
        uint256 bal = auction.bids[_user];
        auction.bids[_user] = 0;
        erc20.transferFrom(address(this), _user, bal);
        emit Withdraw(_user, bal);
    }

    // End auction
    function end(
        address _tokenAddress,
        address _pool,
        uint256 _nftId
    ) external nonReentrant returns (bool) {
        Auction storage auction = auctions[_tokenAddress][_nftId];
        require(
            msg.sender ==
                IStrikeController(maincontract).getPoolFromTokenAddress(
                    _tokenAddress
                ),
            "Call this function from pool contract"
        );
        require(auction.isGoing, "Auction not started");
        require(
            block.timestamp >= auction.tlastBid + interval,
            "Auction is still ongoing!"
        );
        require(auction.actualBidder != address(0), "no bids");
        auction.isGoing = false;
        auction.bids[auction.actualBidder] = 0;
        //Transfers the NFT to the actualBidder and erc20 to stakeholders
        IERC721(_tokenAddress).safeTransferFrom(
            address(_pool),
            auction.actualBidder,
            _nftId
        );
        erc20.transfer(auction.optionOwner, auction.debt);
        erc20.transfer(
            auction.optionWriter,
            ((auction.highestBid - auction.debt) * liquidationRatio) / 1000
        );

        emit End(auction.actualBidder, auction.highestBid);
        return true;
    }

    function setMainContact(address _mainConctract) public onlyOwner {
        maincontract = _mainConctract;
    }

    function getAuction(
        address _tokenAddress,
        uint256 _tokenId
    ) public view returns (AuctionLight memory auctionLight) {
        Auction storage auction = auctions[_tokenAddress][_tokenId];
        auctionLight = AuctionLight({
            highestBid: auction.highestBid,
            actualBidder: auction.actualBidder,
            optionWriter: auction.optionWriter,
            optionOwner: auction.optionOwner,
            debt: auction.debt,
            tlastBid: auction.tlastBid,
            isGoing: auction.isGoing
        });
        return auctionLight;
    }

    /*** Admins functions ***/

    function setLiquidationRatio(uint256 _liquidationRatio) public onlyOwner {
        require(
            _liquidationRatio <= 1000,
            "Liquidation ratio must be less than 1000"
        );
        require(
            _liquidationRatio > 0,
            "Liquidation ratio must be greater than 0"
        );
        liquidationRatio = _liquidationRatio;
    }

    function setFirstBidRatio(uint256 _firstBidRatio) public onlyOwner {
        require(
            _firstBidRatio <= 1000,
            "First bid ratio must be less than 1000"
        );
        require(_firstBidRatio > 0, "First bid ratio must be greater than 0");
        firstBidRatio = _firstBidRatio;
    }

    function setMinBidRatio(uint256 _minBidRatio) public onlyOwner {
        require(
            _minBidRatio >= 1000,
            "Min bid ratio must be greater than 1000"
        );
        require(_minBidRatio < 2000, "Min bid ratio must be less than 2000");
        minBidRatio = _minBidRatio;
    }
}
