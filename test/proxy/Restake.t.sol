// SPDX-License-Identifier: UNLICENSEDauctionERCManager
pragma solidity ^0.8.13;

import "../../src/StrikePool.sol";
import "../../src/StrikeController.sol";
import "../../src/mocks/MockERC721.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/interfaces/IStrikePool.sol";
import "../../src/AuctionManager.sol";
import "../../src/libraries/OptionPricing.sol";
import "../../src/mocks/MockOracle.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract RestakeNFTsTest is Test {
    IStrikePool public strikePoolProxy;
    StrikeController public strikeController;
    StrikePool public strikePoolV1;
    AuctionManager public auctionManager;
    MockERC721 public erc721;
    MockERC20 public erc20;
    OptionPricingSimple public optionPricing;
    MockOracle public mockOracle;
    uint256 public epochduration;
    uint256 public interval;

    uint256 internal ownerPrivateKey;
    uint256 internal spenderPrivateKey;
    uint256 internal thirdPrivateKey;

    address internal alice;
    address internal bob;
    address internal alex;

    uint256 internal tokenMinted;
    uint256 internal tokenMinted_bis;

    function setUp() public {
        ownerPrivateKey = 0xA11CE;
        spenderPrivateKey = 0xB0B;
        thirdPrivateKey = 0xA732;

        payable(alice).transfer(10 ether);
        payable(bob).transfer(10 ether);
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
        strikePrices[0] = 2 ether;
        strikePoolProxy.setStrikePriceAt(1, strikePrices);
        strikePoolProxy.setStrikePriceAt(2, strikePrices);
        epochduration = strikePoolProxy.getEpochDuration();
        interval = strikePoolProxy.getInterval();
        /*** Set-up user  ***/
        alice = vm.addr(ownerPrivateKey);
        bob = vm.addr(spenderPrivateKey);
        alex = vm.addr(spenderPrivateKey);
        /*** Bob mint NFTs and stakes***/
        vm.startPrank(bob);
        tokenMinted = erc721.freemint();
        tokenMinted_bis = erc721.freemint();
        erc721.approve(address(strikePoolProxy), tokenMinted);
        erc721.approve(address(strikePoolProxy), tokenMinted_bis);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenMinted;
        tokenIds[1] = tokenMinted_bis;
        strikePoolProxy.stakeNFTs(tokenIds, 2 ether);
        vm.stopPrank();

        /*** Alice mint erc20 ***/
        vm.stopPrank();
        vm.startPrank(alice);
        erc20.freemint();
        erc20.approve(address(strikePoolProxy), 2 ether);
        vm.stopPrank();

        /*** Alice buy Options ***/
        vm.warp(epochduration + interval);
        vm.startPrank(alice);
        strikePoolProxy.buyOptions(2 ether, 2);
        vm.stopPrank();

        /*** Set the floor price for epoch 1 ***/
        // option expires worthless
        strikePoolProxy.setFloorPriceAt(1, 1 ether);
    }

    function testRestake() public {
        vm.warp(2 * epochduration - interval);

        vm.startPrank(bob);
        //create a calldata array with tokenIds to restakeNFTs
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenMinted;
        tokenIds[1] = tokenMinted_bis;
        strikePoolProxy.restakeNFTs(tokenIds, 2 ether);
    }
}
