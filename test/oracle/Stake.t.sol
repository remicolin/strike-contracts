// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "../common/CommonStrikeTestChainlink.sol";

contract TestStake is CommonStrikeTestChainlink {

    function setUp() public {
        _commonSetup();
    }

    function testStakeOption() public {
        vm.startPrank(bob);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        strikePoolProxy.stakeNFTs(tokenIds, strikePrice1);
        vm.stopPrank();

        uint256 optionBalanceOfBob = strikePoolProxy.getOptionBalanceOf(bob);
        assertEq(optionBalanceOfBob, 3);

        vm.startPrank(alice);
        tokenIds[0] = 10;
        tokenIds[1] = 11;
        tokenIds[2] = 12;
        strikePoolProxy.stakeNFTs(tokenIds, strikePrice1);
        vm.stopPrank();

        uint256 optionBalanceOfAlice = strikePoolProxy.getOptionBalanceOf(alice);
        assertEq(optionBalanceOfAlice, 3);

        vm.startPrank(bob);
        tokenIds[0] = 3;
        tokenIds[1] = 4;
        tokenIds[2] = 5;
        strikePoolProxy.stakeNFTs(tokenIds, strikePrice1);
        vm.stopPrank();

        optionBalanceOfBob = strikePoolProxy.getOptionBalanceOf(bob);
        assertEq(optionBalanceOfBob, 6);

        // Checking ids of bob enumerable

        for (uint i = 0; i < optionBalanceOfBob; i++) {
            uint256 tokenId = strikePoolProxy.getOptionOfOwnerByIndex(bob, i);
            assertEq(tokenId, i);
        }

        // checking ids of alice enumerable

        for (uint i = 0; i < optionBalanceOfAlice; i++) {
            uint256 tokenId = strikePoolProxy.getOptionOfOwnerByIndex(alice, i);
            assertEq(tokenId, i + 10);
        }
    }

    function testStakeOptionFail() public {
        vm.startPrank(alex);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        vm.expectRevert(bytes('ERC721: transfer from incorrect owner'));
        strikePoolProxy.stakeNFTs(tokenIds, strikePrice1);
        vm.stopPrank();
    }

}
