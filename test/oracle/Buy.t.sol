// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "../common/CommonStrikeTestChainlink.sol";

contract TestBuy is CommonStrikeTestChainlink {

    function setUp() public {
        _commonSetup();
        _stakeSetup();

    }

    function testBuyOption() public {
        vm.warp(epochduration + interval);
        vm.startPrank(alice);
        strikePoolProxy.buyOptions(strikePrice1, 2);
        uint requestId = 1;
        mockOracle.executeOracle(bytes32(requestId));
        vm.stopPrank();

        //get enumerable of bob 
        uint256 bobBalance = strikePoolProxy.getOptionBalanceOf(bob);
        for (uint i = 0; i < bobBalance; i++) {
            uint256 tokenId = strikePoolProxy.getOptionOfOwnerByIndex(bob, i);
        }
    }

}
