// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract MockOracle {
    uint256 public volatility = 10;
    uint256 public floorPrice = 2 ether;

    constructor(uint256 _volatility) {
        volatility = _volatility;
    }

    function setVolatility(uint256 _volatility) external {
        volatility = _volatility;
    }

    function getVolatility(address _erc721) external view returns (uint256) {
        return volatility;
    }

    function setFloorPrice(uint256 _floorPrice) external {
        floorPrice = _floorPrice;
    }

    function getFloorPrice(address _erc721) external view returns (uint256) {
        return floorPrice;
    }

    function getVolatilityAndFloorPrice(
        address _erc721
    ) external view returns (uint256, uint256) {
        return (volatility, floorPrice);
    }
}
