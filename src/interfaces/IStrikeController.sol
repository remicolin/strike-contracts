// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.13;

interface IStrikeController {
    function deployPool(address _erc721) external returns (address pool);

    function getPoolFromTokenAddress(
        address _tokenAddress
    ) external view returns (address);

    function setAuctionManager(address _auctionManager) external;

    function getOptionPricing() external view returns (address);

    function getVolatilityOracle() external view returns (address);

    /*** Call PoolContract - getters functions  ***/

    function getFloorPrice(
        address _pool,
        uint256 _epoch
    ) external view returns (uint256);

    function getEpoch_2e(address _pool) external view returns (uint256);

    function getSharesAtOf(
        address _pool,
        uint256 _epoch,
        uint256 _strikePrice,
        address _add
    ) external view returns (uint256);

    function getAmountLockedAt(
        address _pool,
        uint256 _epoch,
        uint256 _strikePrice
    ) external view returns (uint256);

    function getOptionAvailableAt(
        address _pool,
        uint256 _epoch,
        uint256 _strikePrice
    ) external view returns (uint256);

    function getEpochDuration(
        address _pool
    ) external view returns (uint256 epochduration);

    function getInterval(
        address _pool
    ) external view returns (uint256 interval);

    /***Call Auction Contract ***/

    function bid(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _amount
    ) external;

    function endAuction(address _tokenAddress, uint256 _tokenId) external;

    function setPoolImplementation(address _poolImplementation) external;
}
