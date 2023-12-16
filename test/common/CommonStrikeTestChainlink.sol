// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "../../src/oracle/StrikePoolChainlink.sol";
import "../../src/StrikeController.sol";
import "../../src/mocks/MockERC721.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/interfaces/IStrikePoolChainlink.sol";
import "../../src/AuctionManager.sol";
import "../../src/libraries/OptionPricing.sol";
import "../../src/mocks/MockChainlinkOracle.sol";

contract CommonStrikeTestChainlink is Test {
    AuctionManager public auctionManager;
    StrikeController public strikeController;
    IStrikePoolChainlink public strikePoolProxy;
    StrikePoolChainlink public strikePoolV1;
    MockERC721 public erc721;
    MockERC20 public erc20;
    OptionPricingSimple public optionPricing;
    MockChainlinkOracle public mockOracle;

    uint256 public epochduration;
    uint256 public interval;

    uint256 public strikePrice1 = 2 ether;

    address internal alice;
    address internal bob;
    address internal alex;
    address internal tom;

    function _commonSetup() public {
        /*** Deploy contracts***/
        erc20 = new MockERC20("EGOLD token", "GLD");
        erc721 = new MockERC721();
        strikeController = new StrikeController(address(erc20));
        strikePoolV1 = new StrikePoolChainlink();
        strikeController.setPoolImplementation(address(strikePoolV1));
        auctionManager = new AuctionManager(address(erc20));
        optionPricing = new OptionPricingSimple(1000, 1);
        mockOracle = new MockChainlinkOracle(100);

        /*** Set up contracts***/
        auctionManager.setMainContact(address(strikeController));
        strikeController.setAuctionManager(address(auctionManager));
        strikeController.setOracle(address(mockOracle));
        strikeController.setOptionPricing(address(optionPricing));
        strikePoolProxy = IStrikePoolChainlink(
            strikeController.deployPoolChainlink(address(erc721))
        );
        uint256[] memory strikePrices = new uint256[](1);
        strikePrices[0] = strikePrice1;
        strikePoolProxy.setStrikePriceAt(1, strikePrices);
        strikePoolProxy.setStrikePriceAt(2, strikePrices);
        epochduration = strikePoolProxy.epochduration();
        interval = strikePoolProxy.interval();

        /*** Set-up user  ***/
        alice = vm.addr(0xA11CE);
        bob = vm.addr(0xB0B);
        alex = vm.addr(0xA732);
        tom = vm.addr(0x123);

        payable(alice).transfer(10 ether);
        payable(bob).transfer(10 ether);
        payable(alex).transfer(10 ether);
        payable(tom).transfer(10 ether);

        vm.startPrank(bob);
        erc721.freemint10();
        erc721.setApprovalForAll(address(strikePoolProxy),true);
        erc20.freemint();
        erc20.approve(address(strikePoolProxy), 10 ether);
        vm.stopPrank();
        vm.startPrank(alice);
        erc20.freemint();
        erc20.approve(address(strikePoolProxy), 10 ether);
        erc721.freemint10();
        erc721.setApprovalForAll(address(strikePoolProxy),true);
        vm.stopPrank();
       
    }

    function _stakeSetup() public {
        vm.startPrank(bob);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        strikePoolProxy.stakeNFTs(tokenIds, strikePrice1);
        vm.stopPrank();
        }

    function _complexStakeSetup() public {
        vm.startPrank(bob);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        strikePoolProxy.stakeNFTs(tokenIds, strikePrice1);
        vm.stopPrank();

        vm.startPrank(alice);
        tokenIds[0] = 10;
        tokenIds[1] = 11;
        tokenIds[2] = 12;
        strikePoolProxy.stakeNFTs(tokenIds, strikePrice1);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenIds[0] = 3;
        tokenIds[1] = 4;
        tokenIds[2] = 5;
        strikePoolProxy.stakeNFTs(tokenIds, strikePrice1);
        vm.stopPrank();
    }

    function _buySetup() public {
        vm.warp(epochduration + interval);
        vm.startPrank(alice);
        uint requestId = 1;
        strikePoolProxy.buyOptions(strikePrice1, 2);
        mockOracle.executeOracle(bytes32(requestId));
        vm.stopPrank();
    }

}