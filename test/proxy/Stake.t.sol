// SPDX-License-Identifier: UNLICENSEDauctionERCManager
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "../common/CommonStrikeTest.sol";


contract StakeTest is CommonStrikeTest {

   function setUp() public {
    _commonSetup();
    }

    function testStakeNFTs() public {
        vm.startPrank(bob);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        strikePoolProxy.stakeNFTs(tokenIds, strikePrice1);
        vm.stopPrank();
    }

    function testStakeNFTsFail() public {
        vm.startPrank(alex);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        vm.expectRevert(bytes('ERC721: transfer from incorrect owner'));
        strikePoolProxy.stakeNFTs(tokenIds, strikePrice1);
        vm.stopPrank();
    }

    function testStakeNFTsSPFail() public {
        vm.startPrank(bob);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 4;
        vm.expectRevert(bytes('Wrong strikePrice'));
        strikePoolProxy.stakeNFTs(tokenIds, strikePrice1 +1);
        vm.stopPrank();
    }

}
