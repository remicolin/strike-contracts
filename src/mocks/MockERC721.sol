// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MockERC721 is ERC721Enumerable {
    uint256 public nftId;
    address public auctionContract;
    address public owner;

    constructor() ERC721("MockERC721", "INFT") {
        owner = msg.sender;
    }

    /*** Use this function to get free erc721 token ***/
    function freemint() external returns (uint256) {
        _mint(msg.sender, nftId);
        uint256 currentId = nftId;
        nftId++;
        return currentId;
    }

    /*** Use this function to get 10 free erc721 tokens ***/
    function freemint10() external {
        for (uint256 i = 0; i < 10; i++) {
            _mint(msg.sender, nftId);
            nftId++;
        }
    }
}
