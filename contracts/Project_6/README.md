# 6. Simple NFT Marketplace

Sellers can sell() their NFT while specifying a price and expiration. Instead of depositing the NFT into the contract, they give the contract approval to withdraw it from them. If a buyer comes along and pays the specified price before the expiration, then the NFT is transferred from the seller to the buyer and the buyer’s ether is transferred to the seller. The seller can cancel() the sale at any time. Corner cases:

    What if the seller lists the same NFT twice? This can theoretically happen since they don’t transfer the NFT to the marketplace.

## Solution

The solution consists of two smart contracts:

1. **SimpleNFT.sol**: An ERC721 token that allows minting.
2. **Marketplace.sol**: Handles listing, buying, and cancelling of NFTs.

**Key Implementation Details:**

- **Off-Contract State**: The NFT remains in the seller's wallet until purchase. The marketplace uses `transferFrom` to move the token.
- **Approval Check**: To list an item, the seller must first `approve` the marketplace contract. The `listOnSale` function explicitly verifies this approval to prevent invalid listings.
- **Safety**: The contract includes checks for ownership (`NotOwner`), listing status (`NotOnSale`), and invalid parameters.
- **Events**: Emits `NFTListed`, `NFTBought`, and `ListingCancelled` for frontend indexing.

## Usage

```solidity
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
```
