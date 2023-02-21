// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.10;

interface IAuctionManager {
    event Start(uint256 _nftId, uint256 startingBid);
    event End(address actualBidder, uint256 highestBid);
    event Bid(address indexed sender, uint256 amount);
    event Withdraw(address indexed bidder, uint256 amount);

    function start(
        address _tokenAddress,
        uint256 _nftId,
        uint256 _startingBid,
        address _optionWriter,
        address _optionOwner,
        uint256 _debt
    ) external;

    function bid(
        address _tokenAddress,
        uint256 _nftId,
        uint256 _bidAmount,
        address _user
    ) external;

    //  Users can retract at any times if they aren't the actual bidder
    function withdraw(address _user) external;

    // End auction
    function end(
        address _tokenAddress,
        address _pool,
        uint256 _nftId
    ) external returns (bool);
}
