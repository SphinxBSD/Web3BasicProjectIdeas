// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Marketplace {
    struct NFTOnSale {
        address payable seller;
        address tokenContract;
        uint256 tokenId;
        uint256 price;
        uint256 expiresAt;
        bool isOnSale;
    }

    uint256 private _nextTokenId;

    mapping(uint256 => NFTOnSale) public listNFTOnSale;

    event NFTBought(
        uint256 indexed listingId,
        address indexed buyer,
        address tokenContract,
        uint256 tokenId
    );

    event NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address tokenContract,
        uint256 tokenId,
        uint256 price,
        uint256 expiresAt
    );

    event ListingCancelled(uint256 indexed listingId);

    error InvalidPrice();
    error InvalidExpirationTime();
    error InvalidTokenContract();
    error InvalidTokenId();
    error NotOwner();
    error InvalidAmount();
    error NotOnSale();
    error NotApproved();

    function listOnSale(
        address tokenContract,
        uint256 tokenId,
        uint256 price,
        uint256 expiresAt
    ) public {
        if (price <= 0) revert InvalidPrice();
        if (expiresAt <= block.timestamp) revert InvalidExpirationTime();
        if (tokenContract == address(0)) revert InvalidTokenContract();

        IERC721 erc721Token = IERC721(tokenContract);
        if (erc721Token.ownerOf(tokenId) != msg.sender) revert NotOwner();

        if (
            erc721Token.getApproved(tokenId) != address(this) &&
            !erc721Token.isApprovedForAll(msg.sender, address(this))
        ) revert NotApproved();

        uint256 listingId = _nextTokenId++;
        listNFTOnSale[listingId] = NFTOnSale({
            seller: payable(msg.sender),
            tokenContract: tokenContract,
            tokenId: tokenId,
            price: price,
            expiresAt: expiresAt,
            isOnSale: true
        });

        emit NFTListed(
            listingId,
            msg.sender,
            tokenContract,
            tokenId,
            price,
            expiresAt
        );
    }

    function buyNFT(uint256 listingId) public payable {
        NFTOnSale storage nftOnSale = listNFTOnSale[listingId];
        if (!nftOnSale.isOnSale) revert NotOnSale();

        if (nftOnSale.expiresAt < block.timestamp)
            revert InvalidExpirationTime();
        if (nftOnSale.price != msg.value) revert InvalidAmount();

        IERC721 erc721Token = IERC721(nftOnSale.tokenContract);

        nftOnSale.isOnSale = false;
        erc721Token.transferFrom(
            nftOnSale.seller,
            msg.sender,
            nftOnSale.tokenId
        );
        (bool success, ) = nftOnSale.seller.call{value: msg.value}("");
        require(success, "Transfer failed");

        emit NFTBought(
            listingId,
            msg.sender,
            nftOnSale.tokenContract,
            nftOnSale.tokenId
        );
    }

    function cancelListing(uint256 listingId) public {
        NFTOnSale storage nftOnSale = listNFTOnSale[listingId];
        if (nftOnSale.seller != msg.sender) revert NotOwner();
        if (!nftOnSale.isOnSale) revert NotOnSale();
        nftOnSale.isOnSale = false;

        emit ListingCancelled(listingId);
    }
}
