// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/StrikePool.sol";
import "../src/StrikeController.sol";
import "../src/mocks/MockERC721.sol";
import "../src/mocks/MockERC20.sol";
import "../src/interfaces/IStrikePool.sol";
import "../src/AuctionManager.sol";
import "../src/libraries/OptionPricing.sol";
import "../src/mocks/MockOracle.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract CoverPosition is Test {
    IStrikePool public strikePool;
    StrikeController public strikeController;
    AuctionManager public auctionManager;
    OptionPricingSimple public optionPricing;
    MockOracle public mockOracle;
    MockERC721 public erc721;
    MockERC20 public erc20;
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
    uint256 internal tokenMinted_third;
    uint256 internal tokenMinted_fourth;

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
        strikePool = IStrikePool(strikeController.deployPool(address(erc721)));
        auctionManager = new AuctionManager(address(erc20));
        optionPricing = new OptionPricingSimple(1000, 1);
        mockOracle = new MockOracle(100);
        /*** Set up contracts***/
        auctionManager.setMainContact(address(strikeController));
        strikeController.setAuctionManager(address(auctionManager));
        strikeController.setVolatilityOracle(address(mockOracle));
        strikeController.setOptionPricing(address(optionPricing));
        uint256[] memory strikePrices = new uint256[](1);
        strikePrices[0] = 2 ether;
        strikePool.setStrikePriceAt(1, strikePrices);
        strikePool.setStrikePriceAt(3, strikePrices);
        epochduration = strikePool.getEpochDuration();
        interval = strikePool.getInterval();
        /*** Set-up user  ***/
        alice = vm.addr(ownerPrivateKey);
        bob = vm.addr(spenderPrivateKey);
        alex = vm.addr(spenderPrivateKey);
        /*** Bob mint NFTs, erc20 and stakes***/
        vm.startPrank(bob);
        tokenMinted = erc721.freemint();
        tokenMinted_bis = erc721.freemint();
        tokenMinted_third = erc721.freemint();
        tokenMinted_fourth = erc721.freemint();
        erc721.approve(address(strikePool), tokenMinted);
        erc721.approve(address(strikePool), tokenMinted_bis);
        erc721.approve(address(strikePool), tokenMinted_third);
        erc20.freemint();
        strikePool.stakeNFTs(tokenMinted, 2 ether);
        strikePool.stakeNFTs(tokenMinted_bis, 2 ether);
        vm.warp(2 * epochduration + 1);
        strikePool.stakeNFTs(tokenMinted_third, 2 ether);
        vm.warp(1);
        vm.stopPrank();
        /*** Alice mint erc20 and buy option ***/
        vm.stopPrank();
        vm.startPrank(alice);
        erc20.freemint();
        erc20.approve(address(strikePool), 2 ether);
        vm.stopPrank();
        vm.startPrank(alice);
        vm.warp(epochduration + 1);
        strikePool.buyOption(2 ether);
        IStrikePool.Option memory option = strikePool.getOption(
            tokenMinted_bis
        );
        assertEq(option.buyer, alice);
        vm.stopPrank();
        strikePool.setFloorPriceAt(1, 3 ether);
    }

    function testCoverPositionNotBought() public {
        vm.warp(2 * epochduration - interval);
        vm.startPrank(bob);
        vm.expectRevert(bytes("Option have not been bought"));
        strikePool.coverPosition(tokenMinted);
        vm.stopPrank();
    }

    function testCoverPositionWithoutAllowance() public {
        vm.warp(2 * epochduration - interval);
        vm.startPrank(bob);
        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        strikePool.coverPosition(tokenMinted_bis);
        vm.stopPrank();
    }

    function testCoverPosition() public {
        vm.warp(2 * epochduration - interval);
        vm.startPrank(bob);
        erc20.approve(address(strikePool), 1 ether);
        strikePool.coverPosition(tokenMinted_bis);
        vm.stopPrank();
    }

    function testCoverPositionBeforeAllowed() public {
        vm.warp(4 * epochduration - interval);
        vm.startPrank(bob);
        erc20.approve(address(strikePool), 1 ether);
        strikePool.coverPosition(tokenMinted_bis);
        vm.stopPrank();
    }
}
