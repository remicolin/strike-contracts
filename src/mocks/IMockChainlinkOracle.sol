// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IMockChainlinkOracle {

    function requestOracle(
        address _erc721, uint256 _strikePrice
    ) external  returns (bytes32);
}
