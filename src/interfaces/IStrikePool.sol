// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.13;

interface IStrikePool {
    struct Option {
        address writer;
        address buyer;
        uint256 sPrice;
        uint256 epoch;
        bool covered;
        bool liquidated;
    }

    function initialize(
        address _erc721,
        address _erc20,
        address _auctionManager,
        address _baseCurrency,
        address _oo
    ) external;

    /*** Staker functions ***/

    function stakeNFTs(uint256 _tokenId, uint256 _strikePrice) external;

    function stakeNFTs(
        uint256[] memory _tokenIds,
        uint256 _strikePrice
    ) external;

    function restakeNFTs(uint256 _tokenId, uint256 _strikePrice) external;

    function restakeNFTs(
        uint256[] memory _tokenIds,
        uint256 _strikePrice
    ) external;

    function withdrawNFT(uint256 _tokenId) external;

    function claimPremiums(uint256 _epoch, uint256 _strikePrice) external;

    /*** Buyer functions ***/

    function buyOption(uint256 _strikePrice) external;

    function buyOptions(uint256 _strikePrice, uint256 _amount) external;

    function coverPosition(uint256 _tokenId) external;

    function buyAtStrike(uint256 _tokenId) external;

    function liquidateNFT(uint256 _tokenId) external;

    /*** Auction functions ***/

    function bidAuction(uint256 _tokenId, uint256 _amount) external;

    function endAuction(uint256 _tokenId) external;

    /*** Admin functions ***/

    function setStrikePriceAt(
        uint256 _epoch,
        uint256[] memory _strikePrices
    ) external;

    function setFloorPriceAt(uint256 _epoch, uint256 _floorPrice) external;

    function setAuctionManager(address _auctionManager) external;

    /*** Getters ***/

    function getFloorPrice(uint256 _epoch) external view returns (uint256);

    function getEpoch_2e() external view returns (uint256);

    function getSharesAtOf(
        uint256 _epoch,
        uint256 _strikePrice,
        address _add
    ) external view returns (uint256);

    function getOption(
        uint256 _tokenId
    ) external view returns (Option memory option);

    function getAmountLockedAt(
        uint256 _epoch,
        uint256 _strikePrice
    ) external view returns (uint256);

    function getOptionAvailableAt(
        uint256 _epoch,
        uint256 _strikePrice
    ) external view returns (uint256);

    function getEpochDuration() external view returns (uint256 epochduration);

    function getInterval() external view returns (uint256 interval);

    function epochduration() external view returns (uint256 epochduration);
}
