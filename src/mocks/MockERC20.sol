// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /*** Use this function to get free erc20 tokens ***/
    function freemint() public {
        _mint(msg.sender, 5000 * 10 ** 18);
    }
}
