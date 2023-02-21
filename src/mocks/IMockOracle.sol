// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IMockOracle {
    function getVolatility(address _erc721) external view returns (uint256);

    function getFloorPrice(address _erc721) external view returns (uint256);

    function getVolatilityAndFloorPrice(
        address _erc721
    ) external view returns (uint256, uint256);
}
