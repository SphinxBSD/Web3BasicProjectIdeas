// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "./Marketplace.sol";
import "./SimpleNFT.sol";

contract MarketplaceTest is Test {
    Marketplace marketplace;
    SimpleNFT nft;

    address seller = address(0x1);
    address buyer = address(0x2);

    function setUp() public {
        // Deploy contracts
        // Seller is the owner of the NFT contract to allow minting
        nft = new SimpleNFT(seller);
        marketplace = new Marketplace();

        // Mint an NFT to the seller
        vm.startPrank(seller);
        nft.safeMint(seller); // TokenId 0
        vm.stopPrank();

        // Give the buyer some ether
        vm.deal(buyer, 10 ether);
    }

    function testListAndBuy() public {
        uint256 price = 1 ether;
        uint256 tokenId = 0;

        // 1. Seller approves and lists
        vm.startPrank(seller);
        nft.approve(address(marketplace), tokenId);
        marketplace.listOnSale(
            address(nft),
            tokenId,
            price,
            block.timestamp + 1 days
        );
        vm.stopPrank();

        // 2. Buyer buys
        vm.startPrank(buyer);
        marketplace.buyNFT{value: price}(0); // ListingId 0
        vm.stopPrank();

        // 3. Verify ownership transfer
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(seller.balance, price);
    }

    function testCancelListing() public {
        uint256 price = 1 ether;
        uint256 tokenId = 0;
        uint256 listingId = 0;

        // 1. Seller lists
        vm.startPrank(seller);
        nft.approve(address(marketplace), tokenId);
        marketplace.listOnSale(
            address(nft),
            tokenId,
            price,
            block.timestamp + 1 days
        );

        // 2. Seller cancels
        marketplace.cancelListing(listingId);
        vm.stopPrank();

        // 3. Buyer tries to buy (should fail)
        vm.startPrank(buyer);
        vm.expectRevert(Marketplace.NotOnSale.selector);
        marketplace.buyNFT{value: price}(listingId);
        vm.stopPrank();
    }

    function testCannotListWithoutApproval() public {
        uint256 price = 1 ether;
        uint256 tokenId = 0;

        // 1. Seller tries to list WITHOUT approving Marketplace first
        vm.startPrank(seller);

        vm.expectRevert(Marketplace.NotApproved.selector);
        marketplace.listOnSale(
            address(nft),
            tokenId,
            price,
            block.timestamp + 1 days
        );

        vm.stopPrank();
    }
}
