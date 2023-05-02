// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "../../src/StrikePool.sol";
import "../../src/StrikeController.sol";
import "../../src/mocks/MockERC721.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/interfaces/IStrikePool.sol";
import "../../src/AuctionManager.sol";
import "../../src/libraries/OptionPricing.sol";
import "../../src/mocks/MockOracle.sol";
import "./CommonOptimisticOracleV3Test.sol";

contract CommonStrikeTest is Test, CommonOptimisticOracleV3Test {
    AuctionManager public auctionManager;
    StrikeController public strikeController;
    IStrikePool public strikePoolProxy;
    StrikePool public strikePoolV1;
    MockERC721 public erc721;
    MockERC20 public erc20;
    OptionPricingSimple public optionPricing;
    MockOracle public mockOracle;

    uint256 public epochduration;
    uint256 public interval;

    uint256 public strikePrice1 = 2 ether;

    address internal alice;
    address internal bob;
    address internal alex;
    address internal tom;

    function _commonSetup() public {
        _commonSetupOracle();
        /*** Deploy contracts***/
        erc20 = new MockERC20("EGOLD token", "GLD");
        erc721 = new MockERC721();
        strikeController = new StrikeController(address(erc20));
        strikePoolV1 = new StrikePool();
        strikeController.setPoolImplementation(address(strikePoolV1));
        auctionManager = new AuctionManager(address(erc20));
        optionPricing = new OptionPricingSimple(1000, 1);
        mockOracle = new MockOracle(100);

        /*** Set up contracts***/
        auctionManager.setMainContact(address(strikeController));
        strikeController.setAuctionManager(address(auctionManager));
        strikeController.setVolatilityOracle(address(mockOracle));
        strikeController.setOptionPricing(address(optionPricing));
        strikePoolProxy = IStrikePool(
            strikeController.deployPool(address(erc721))
        );
        uint256[] memory strikePrices = new uint256[](1);
        strikePrices[0] = strikePrice1;
        strikePoolProxy.setStrikePriceAt(1, strikePrices);
        strikePoolProxy.setStrikePriceAt(2, strikePrices);
        epochduration = strikePoolProxy.getEpochDuration();
        interval = strikePoolProxy.getInterval();

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

    function _buySetup() public {
        vm.warp(epochduration + interval);
        vm.startPrank(alice);
        strikePoolProxy.buyOptions(strikePrice1, 2);
        vm.stopPrank();
    }

    function _umaSetup() public {
        defaultCurrency.allocateTo(bob,10 ether);
    }
    


}