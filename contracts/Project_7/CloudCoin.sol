// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CloudCoin is ERC20, Ownable {
    uint256 private _totalSupply;

    constructor(
        address initialOwner
    ) ERC20("CloudCoin", "CLOUD") Ownable(initialOwner) {
        _totalSupply = 1_000_000 * 1e18;
        _mint(initialOwner, _totalSupply);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
