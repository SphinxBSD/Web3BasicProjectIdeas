// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTWithToken is ERC721, Ownable {
    uint256 private _nextTokenId;
    uint256 public price;
    IERC20 public immutable paymentToken;

    // Events
    event NFTMinted(address indexed minter, uint256 indexed tokenId, uint256 price);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event FundsWithdrawn(address indexed to, uint256 amount);

    // Errors
    error InsufficientAllowance();
    error InsufficientBalance();
    error TransferFailed();

    constructor(
        address initialOwner,
        address _paymentToken,
        uint256 initialPrice
    ) ERC721("SimpleNFT", "SNFT") Ownable(initialOwner) {
        require(_paymentToken != address(0), "Invalid token address");
        paymentToken = IERC20(_paymentToken);
        price = initialPrice;
    }

    function mint() external {

        if (paymentToken.balanceOf(msg.sender) < price) {
            revert InsufficientBalance();
        }

        if (paymentToken.allowance(msg.sender, address(this)) < price) {
            revert InsufficientAllowance();
        }

        bool success = paymentToken.transferFrom(msg.sender, address(this), price);
        if (!success) {
            revert TransferFailed();
        }

        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);

        emit NFTMinted(msg.sender, tokenId, price);
    }

    function setPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = price;
        price = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }

    function withdraw(address to) external onlyOwner {
        uint256 balance = paymentToken.balanceOf(address(this));
        require(balance > 0, "No funds to withdraw");
        
        bool success = paymentToken.transfer(to, balance);
        require(success, "Transfer failed");
        
        emit FundsWithdrawn(to, balance);
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }
}