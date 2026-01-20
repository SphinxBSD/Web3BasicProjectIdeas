// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract EnglishAuction {
    struct Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 deadline;
        uint256 reservePrice;
        address highestBidder;
        uint256 highestBid;
        bool ended;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public bids;
    uint256 public auctionCounter;

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address nftContract,
        uint256 tokenId,
        uint256 deadline,
        uint256 reservePrice
    );
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );
    event AuctionEnded(
        uint256 indexed auctionId,
        address winner,
        uint256 amount
    );
    event BidWithdrawn(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );

    function deposit(
        address _nftContract,
        uint256 _tokenId,
        uint256 _deadline,
        uint256 _reservePrice
    ) external returns (uint256) {
        require(_deadline > block.timestamp, "Deadline must be in future");

        uint256 auctionId = auctionCounter++;

        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: _nftContract,
            tokenId: _tokenId,
            deadline: _deadline,
            reservePrice: _reservePrice,
            highestBidder: address(0),
            highestBid: 0,
            ended: false
        });

        IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);

        emit AuctionCreated(
            auctionId,
            msg.sender,
            _nftContract,
            _tokenId,
            _deadline,
            _reservePrice
        );
        return auctionId;
    }

    function bid(uint256 _auctionId) external payable {
        Auction storage auction = auctions[_auctionId];
        require(block.timestamp < auction.deadline, "Auction expired");
        require(!auction.ended, "Auction already ended");

        uint256 totalBid = bids[_auctionId][msg.sender] + msg.value;
        require(totalBid > auction.highestBid, "Bid too low");

        bids[_auctionId][msg.sender] = totalBid;
        auction.highestBidder = msg.sender;
        auction.highestBid = totalBid;

        emit BidPlaced(_auctionId, msg.sender, totalBid);
    }

    function withdraw(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];
        require(msg.sender != auction.highestBidder, "Winner cannot withdraw");

        uint256 amount = bids[_auctionId][msg.sender];
        require(amount > 0, "No bid to withdraw");

        bids[_auctionId][msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit BidWithdrawn(_auctionId, msg.sender, amount);
    }

    function sellerEndAuction(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];
        require(msg.sender == auction.seller, "Only seller");
        require(block.timestamp >= auction.deadline, "Auction not expired");
        require(!auction.ended, "Already ended");
        require(auction.highestBid >= auction.reservePrice, "Reserve not met");

        auction.ended = true;

        IERC721(auction.nftContract).transferFrom(
            address(this),
            auction.highestBidder,
            auction.tokenId
        );

        (bool success, ) = auction.seller.call{value: auction.highestBid}("");
        require(success, "Transfer failed");

        emit AuctionEnded(
            _auctionId,
            auction.highestBidder,
            auction.highestBid
        );
    }
}
