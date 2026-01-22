# NFT Swap Contract

> Disclaimer: I used AI in order to generate this README explanation. However I checked everything is correct.

## Overview

A trustless escrow system for peer-to-peer NFT trading. This smart contract enables secure, atomic swaps of NFTs between two parties without requiring intermediaries. Users can create swap agreements where both parties must deposit their NFTs before execution, ensuring a fair exchange.

## Features

- **Trustless Trading**: Eliminates counterparty risk through atomic swaps
- **Time-Limited Agreements**: Configurable swap expiration periods
- **Flexible NFT Support**: Works with any ERC721 compliant NFT
- **Secure Escrow**: NFTs are held securely until swap conditions are met
- **Multiple Recovery Options**: Safe withdrawal mechanisms for expired or cancelled swaps
- **Transparent Tracking**: Comprehensive event logging and view functions

## Contract Structure

### SwapNFT
The main contract that manages all NFT swap agreements with the following key functions:

- `createSwap()`: Establish a new NFT swap agreement between two parties
- `depositNFT()`: Deposit your NFT into the swap escrow
- `executeSwap()`: Complete the swap when both NFTs are deposited
- `cancelSwap()`: Cancel the swap before both parties deposit
- `withdrawAfterExpiration()`: Reclaim NFTs after swap expiration
- `getSwap()`: View detailed swap information

### Example NFT Contracts
Two sample ERC721 contracts for testing purposes:
- **FirstNFT**: "FirstNFT" (FST) token
- **SecondNFT**: "SecondNFT" (SND) token
- Both feature minting functionality with Ownable access control

## How It Works

1. **Swap Creation**: Party A creates a swap specifying:
   - Their NFT contract and token ID
   - Counterparty's address (Party B)
   - Party B's NFT contract and token ID
   - Swap duration in days

2. **Verification**: The contract verifies both parties own their respective NFTs

3. **NFT Deposit**: Each party deposits their NFT into the contract escrow

4. **Swap Execution**: Once both NFTs are deposited, either party can execute the swap to transfer NFTs to their new owners

5. **Completion**: The swap is marked as completed, and NFTs are transferred atomically

## Key Parameters

- **Swap Duration**: Configurable validity period (1+ days)
- **Expiration Handling**: Swaps automatically expire after the set duration
- **Atomic Execution**: Both NFTs transfer simultaneously or not at all
- **Owner Verification**: Only verified NFT owners can create or participate in swaps

## Events

- `SwapCreated`: Emitted when a new swap agreement is established
- `TokenDeposited`: Emitted when a party deposits their NFT
- `SwapCompleted`: Emitted when the swap successfully executes
- `SwapCancelled`: Emitted when a swap is cancelled
- `TokenWithdrawn`: Emitted when NFTs are returned after expiration

## Error Handling

Comprehensive error messages for:
- Invalid addresses or swap durations
- Unauthorized access attempts
- Attempts to deposit NFTs more than once
- Expired or inactive swaps
- Missing NFT ownership verification
- Attempts to execute before both parties deposit

## Safety Mechanisms

- **Expiration Protection**: NFTs cannot be trapped indefinitely
- **Owner Verification**: Prevents fraudulent swap creation
- **Reentrancy Guards**: Status updates before transfers prevent reentrancy attacks
- **Selective Withdrawal**: Only deposited NFTs can be withdrawn
- **Cancellation Rights**: Swaps can be cancelled before both parties deposit

## Use Cases

- Direct NFT trading without intermediaries
- Cross-collection NFT exchanges
- Trustless marketplace transactions
- Gaming asset trading
- Digital collectible exchanges
- Any scenario requiring secure NFT-for-NFT trades

## Technical Details

- **Solidity Version**: ^0.8.28
- **Dependencies**: OpenZeppelin contracts for ERC721 and IERC721Receiver functionality
- **ERC721Receiver**: Implements safe transfer support
- **License**: MIT

The contract implements a robust, secure system for peer-to-peer NFT trading with multiple safeguards against common pitfalls in trustless exchanges.