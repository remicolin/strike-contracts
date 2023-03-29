// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "../common/CommonStrikeTest.sol";

contract BuyTest is CommonStrikeTest {

    function setUp() public {
        _commonSetup();
    }


    function testSetNewAuctionManager() public {
        strikePoolProxy.setAuctionManager(address(0));
    }

    function testSetNewAuctionManagerFail() public {
        vm.startPrank(alex);
        vm.expectRevert(bytes("msg.sender is not admin"));
        strikePoolProxy.setAuctionManager(address(0));
        vm.stopPrank();
    } 
}
