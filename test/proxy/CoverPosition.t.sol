// SPDX-License-Identifier: UNLICENSEDauctionERCManager
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "../common/CommonStrikeTest.sol";


contract CoverPositionTest is CommonStrikeTest {

    function setUp() public {
       _commonSetup();
       _stakeSetup();
       _buySetup();
    }

    function testCoverPosition() public {
        strikePoolProxy.setFloorPriceAt(1,3 ether);
        vm.warp(2 * epochduration - interval);
        vm.startPrank(bob);
        //create a calldata array with tokenIds to restakeNFTs
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        strikePoolProxy.coverPosition(1);
        strikePoolProxy.restakeNFTs(tokenIds, strikePrice1);
    }

    function testCoverPositionFail() public {
        strikePoolProxy.setFloorPriceAt(1,3 ether);
        vm.warp(2 * epochduration - (2*interval+1));
        vm.startPrank(bob);
        //exopse the revert
        vm.expectRevert("Option has not expired");
        strikePoolProxy.coverPosition(1);
    }

    function testRestakeFail() public {
        strikePoolProxy.setFloorPriceAt(1,3 ether);
        vm.warp(2 * epochduration - interval);
        vm.startPrank(bob);
        vm.expectRevert("Cover your position");
        strikePoolProxy.restakeNFTs(2, strikePrice1);
    }
}