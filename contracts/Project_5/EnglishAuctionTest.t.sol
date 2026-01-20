// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {EnglishAuction} from "./EnglishAuction.sol";
import {FirstNFT} from "./FirstNFT.sol";
import {SecondNFT} from "./SecondNFT.sol";

contract EnglishAuctionTest is Test {
    EnglishAuction public auction;
    FirstNFT public firstNFT;
    SecondNFT public secondNFT;

    address public seller = makeAddr("seller");
    address public bidder1 = makeAddr("bidder1");
    address public bidder2 = makeAddr("bidder2");
    address public bidder3 = makeAddr("bidder3");

    uint256 constant RESERVE_PRICE = 1 ether;
    uint256 constant DEADLINE = 7 days;

    function setUp() public {
        auction = new EnglishAuction();
        firstNFT = new FirstNFT(seller);
        secondNFT = new SecondNFT(seller);

        vm.deal(bidder1, 10 ether);
        vm.deal(bidder2, 10 ether);
        vm.deal(bidder3, 10 ether);
    }

    function test_DepositNFT() public {
        vm.startPrank(seller);
        uint256 tokenId = firstNFT.safeMint(seller);
        firstNFT.approve(address(auction), tokenId);
        
        uint256 auctionId = auction.deposit(
            address(firstNFT),
            tokenId,
            block.timestamp + DEADLINE,
            RESERVE_PRICE
        );

        (address _seller, address nftContract, uint256 _tokenId, , uint256 reservePrice, , , ) = auction.auctions(auctionId);
        
        assertEq(_seller, seller);
        assertEq(nftContract, address(firstNFT));
        assertEq(_tokenId, tokenId);
        assertEq(reservePrice, RESERVE_PRICE);
        assertEq(firstNFT.ownerOf(tokenId), address(auction));
        vm.stopPrank();
    }

    function test_RevertDeadlineInPast() public {
        vm.startPrank(seller);
        uint256 tokenId = firstNFT.safeMint(seller);
        firstNFT.approve(address(auction), tokenId);
        
        vm.expectRevert("Deadline must be in future");
        auction.deposit(
            address(firstNFT),
            tokenId,
            block.timestamp - 1,
            RESERVE_PRICE
        );
        vm.stopPrank();
    }

    function test_PlaceBid() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.bid{value: 1.5 ether}(auctionId);

        assertEq(auction.bids(auctionId, bidder1), 1.5 ether);
        (, , , , , address highestBidder, uint256 highestBid, ) = auction.auctions(auctionId);
        assertEq(highestBidder, bidder1);
        assertEq(highestBid, 1.5 ether);
    }

    function test_MultipleBids() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.bid{value: 1.5 ether}(auctionId);

        vm.prank(bidder2);
        auction.bid{value: 2 ether}(auctionId);

        vm.prank(bidder3);
        auction.bid{value: 2.5 ether}(auctionId);

        (, , , , , address highestBidder, uint256 highestBid, ) = auction.auctions(auctionId);
        assertEq(highestBidder, bidder3);
        assertEq(highestBid, 2.5 ether);
    }

    function test_IncrementalBidding() public {
        uint256 auctionId = _createAuction();

        vm.startPrank(bidder1);
        auction.bid{value: 1.5 ether}(auctionId);
        auction.bid{value: 1 ether}(auctionId);
        vm.stopPrank();

        assertEq(auction.bids(auctionId, bidder1), 2.5 ether);
        (, , , , , address highestBidder, uint256 highestBid, ) = auction.auctions(auctionId);
        assertEq(highestBidder, bidder1);
        assertEq(highestBid, 2.5 ether);
    }

    function test_RevertBidTooLow() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.bid{value: 2 ether}(auctionId);

        vm.prank(bidder2);
        vm.expectRevert("Bid too low");
        auction.bid{value: 1.5 ether}(auctionId);
    }

    function test_RevertBidAfterDeadline() public {
        uint256 auctionId = _createAuction();

        vm.warp(block.timestamp + DEADLINE + 1);

        vm.prank(bidder1);
        vm.expectRevert("Auction expired");
        auction.bid{value: 2 ether}(auctionId);
    }

    function test_LoserCanWithdraw() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.bid{value: 1.5 ether}(auctionId);

        vm.prank(bidder2);
        auction.bid{value: 2 ether}(auctionId);

        uint256 balanceBefore = bidder1.balance;
        
        vm.prank(bidder1);
        auction.withdraw(auctionId);

        assertEq(bidder1.balance, balanceBefore + 1.5 ether);
        assertEq(auction.bids(auctionId, bidder1), 0);
    }

    function test_RevertWinnerCannotWithdraw() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.bid{value: 2 ether}(auctionId);

        vm.prank(bidder1);
        vm.expectRevert("Winner cannot withdraw");
        auction.withdraw(auctionId);
    }

    function test_SellerEndAuction() public {
        uint256 auctionId = _createAuction();
        uint256 tokenId = 0;

        vm.prank(bidder1);
        auction.bid{value: 2 ether}(auctionId);

        vm.warp(block.timestamp + DEADLINE + 1);

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(seller);
        auction.sellerEndAuction(auctionId);

        assertEq(firstNFT.ownerOf(tokenId), bidder1);
        assertEq(seller.balance, sellerBalanceBefore + 2 ether);
        
        (, , , , , , , bool ended) = auction.auctions(auctionId);
        assertTrue(ended);
    }

    function test_RevertEndAuctionBeforeDeadline() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.bid{value: 2 ether}(auctionId);

        vm.prank(seller);
        vm.expectRevert("Auction not expired");
        auction.sellerEndAuction(auctionId);
    }

    function test_RevertEndAuctionReserveNotMet() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.bid{value: 0.5 ether}(auctionId);

        vm.warp(block.timestamp + DEADLINE + 1);

        vm.prank(seller);
        vm.expectRevert("Reserve not met");
        auction.sellerEndAuction(auctionId);
    }

    function test_RevertOnlySellerCanEnd() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.bid{value: 2 ether}(auctionId);

        vm.warp(block.timestamp + DEADLINE + 1);

        vm.prank(bidder1);
        vm.expectRevert("Only seller");
        auction.sellerEndAuction(auctionId);
    }

    function test_MultipleAuctions() public {
        // Create first auction
        vm.startPrank(seller);
        uint256 tokenId1 = firstNFT.safeMint(seller);
        firstNFT.approve(address(auction), tokenId1);
        uint256 auctionId1 = auction.deposit(
            address(firstNFT),
            tokenId1,
            block.timestamp + DEADLINE,
            RESERVE_PRICE
        );

        // Create second auction
        uint256 tokenId2 = secondNFT.safeMint(seller);
        secondNFT.approve(address(auction), tokenId2);
        uint256 auctionId2 = auction.deposit(
            address(secondNFT),
            tokenId2,
            block.timestamp + DEADLINE,
            RESERVE_PRICE
        );
        vm.stopPrank();

        // Bid on both
        vm.prank(bidder1);
        auction.bid{value: 2 ether}(auctionId1);

        vm.prank(bidder2);
        auction.bid{value: 3 ether}(auctionId2);

        // End both
        vm.warp(block.timestamp + DEADLINE + 1);

        vm.startPrank(seller);
        auction.sellerEndAuction(auctionId1);
        auction.sellerEndAuction(auctionId2);
        vm.stopPrank();

        assertEq(firstNFT.ownerOf(tokenId1), bidder1);
        assertEq(secondNFT.ownerOf(tokenId2), bidder2);
    }

    function test_RevertDoubleEnd() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.bid{value: 2 ether}(auctionId);

        vm.warp(block.timestamp + DEADLINE + 1);

        vm.startPrank(seller);
        auction.sellerEndAuction(auctionId);
        
        vm.expectRevert("Already ended");
        auction.sellerEndAuction(auctionId);
        vm.stopPrank();
    }

    // Helper function
    function _createAuction() internal returns (uint256) {
        vm.startPrank(seller);
        uint256 tokenId = firstNFT.safeMint(seller);
        firstNFT.approve(address(auction), tokenId);
        uint256 auctionId = auction.deposit(
            address(firstNFT),
            tokenId,
            block.timestamp + DEADLINE,
            RESERVE_PRICE
        );
        vm.stopPrank();
        return auctionId;
    }
}