// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "../common/CommonStrikeTestChainlink.sol";

contract TestCoverPosition is CommonStrikeTestChainlink {

    function setUp() public {
        _commonSetup();
        _complexStakeSetup();
        _buySetup();
    }

    function testCoverPosition() public {
        vm.warp(2*epochduration + interval);
        strikePoolProxy.setFloorPriceAt(1, 3 ether);
        vm.startPrank(alice);
        strikePoolProxy.buyAtStrike(5);
        assert(erc721.ownerOf(5) == alice);
        vm.stopPrank();

        // checking ids of bob enumerable

        uint256 bobBalance = strikePoolProxy.getOptionBalanceOf(bob);
        for (uint i = 0; i < bobBalance; i++) {
            uint256 tokenId = strikePoolProxy.getOptionOfOwnerByIndex(bob, i);
        }
    }
}
