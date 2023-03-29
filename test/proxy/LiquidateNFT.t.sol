// SPDX-License-Identifier: UNLICENSEDauctionERCManager
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "../common/CommonStrikeTest.sol";


contract LiquidateNFTTEST is CommonStrikeTest {
    function setUp() public {
        _commonSetup();
        _stakeSetup();
        _buySetup();
    }

    function testLiquidateNFT() public {
        strikePoolProxy.setFloorPriceAt(1,3 ether);
        vm.startPrank(alice);
        vm.warp(2 * epochduration + 2*interval);
        strikePoolProxy.liquidateNFT(1);
    }
}