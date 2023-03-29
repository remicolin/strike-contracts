// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "../common/CommonStrikeTest.sol";

contract BuyTest is CommonStrikeTest {

    function setUp() public {
        _commonSetup();
        _stakeSetup();
    }

    function testBuyOption() public {
        vm.warp(epochduration + interval);
        vm.startPrank(alice);
        strikePoolProxy.buyOptions(strikePrice1, 2);
        vm.stopPrank();
    }

    function testBuyOptionFail() public{
        vm.warp(epochduration + interval);
        vm.startPrank(alex);
        vm.expectRevert(bytes('ERC20: insufficient allowance'));
        strikePoolProxy.buyOptions(strikePrice1, 2);
        vm.stopPrank();
    }
}
