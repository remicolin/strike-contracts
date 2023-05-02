// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "../common/CommonStrikeTestOracle.sol";

contract OracleTest is CommonStrikeTestOracle {

    function setUp() public {
        _commonSetup();
        _stakeSetup();
        defaultCurrency.allocateTo(alice, 100 ether);
        vm.startPrank(alice);
        defaultCurrency.approve(address(strikePoolProxy), 100 ether);
        vm.stopPrank();
    }

    function testBuyOption() public {
        vm.warp(epochduration + interval);
        vm.startPrank(alice);
        bytes32 assertionId = strikePoolProxy.buyOptions(strikePrice1, 2);
        vm.stopPrank();
        vm.warp(epochduration + interval + 4*3600);
        optimisticOracleV3.settleAssertion(assertionId);

    }

    function testBuyOptionFail() public{
        vm.warp(epochduration + interval);
        vm.startPrank(alex);
        vm.expectRevert(bytes('ERC20: insufficient allowance'));
        strikePoolProxy.buyOptions(strikePrice1, 2);
        vm.stopPrank();
    }
}
