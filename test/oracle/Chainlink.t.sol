// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "../common/CommonStrikeTestChainlink.sol";

contract OracleTest is CommonStrikeTestChainlink {

    function setUp() public {
        _commonSetup();
        _stakeSetup();
        vm.startPrank(alice);
        vm.stopPrank();
    }

    function testBuyOption() public {
        vm.warp(epochduration + interval);
        vm.startPrank(alice);
        strikePoolProxy.buyOptions(strikePrice1, 2);
        uint requestId = 1;
        mockOracle.executeOracle(bytes32(requestId));
        vm.stopPrank();
    }
/*
    function testBuyOptionFail() public{
        vm.warp(epochduration + interval);
        vm.startPrank(alex);
        vm.expectRevert(bytes('ERC20: insufficient allowance'));
        strikePoolProxy.buyOptions(strikePrice1, 2);
        vm.stopPrank();
    } */
}
