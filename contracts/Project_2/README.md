# 2. Time unlocked ERC20 / vesting contract

I decided to use AI in order to make a more detailed explanation of the project's solution. (Hope you can forgive :'v)

# Vesting Contract for ERC20 Tokens

## Overview

A smart contract implementation for token vesting with time-based release schedules. This contract allows payers to lock tokens for recipients, which become gradually available over a specified vesting period.

## Features

- **Time-Based Vesting**: Tokens are released linearly over a configurable number of days
- **Multiple Vesting Schedules**: Support for multiple recipients and vesting schedules
- **Flexible Withdrawals**: Recipients can withdraw available tokens from individual or all vesting schedules
- **ERC20 Compatible**: Works with any standard ERC20 token
- **Transparent Tracking**: Comprehensive view functions to monitor vesting status
- **Revocable Vesting**: Payer can revoke vesting schedules (with refund functionality)

## Contract Structure

### VestingContract
The main contract that manages all vesting schedules with the following key functions:

- `depositTokens()`: Create a new vesting schedule for a recipient
- `withdraw()`: Withdraw available tokens from a specific vesting schedule
- `withdrawAll()`: Withdraw available tokens from all schedules for the caller
- `getReleasableAmount()`: Calculate currently available tokens for withdrawal
- `getVestingInfo()`: Get detailed information about a vesting schedule

### TokenForVesting (Optional)
Example ERC20 token contract for testing purposes, featuring:
- Standard ERC20 implementation with minting functionality
- Ownable pattern for access control

## Key Parameters

- **Vesting Duration**: Configurable number of days over which tokens vest
- **Linear Release**: Tokens become available gradually each day
- **Start Time**: Vesting begins immediately when schedule is created

## Events

- `VestingCreated`: Emitted when a new vesting schedule is established
- `TokensReleased`: Emitted when tokens are successfully withdrawn
- `VestingRevoked`: Emitted when a vesting schedule is cancelled

## Error Handling

Comprehensive error messages for:
- Insufficient token balance or allowance
- Invalid recipient or amount
- Unauthorized access attempts
- Attempts to withdraw from revoked schedules
- Token transfer failures

## Use Cases

- Employee token compensation plans
- Investor lock-up periods
- Advisor reward distribution
- Project milestone-based funding releases
- Any scenario requiring controlled token distribution over time

## Technical Details

- **Solidity Version**: ^0.8.28
- **Dependencies**: OpenZeppelin contracts for ERC20 and Ownable functionality
- **License**: MIT

The contract implements a secure, gas-efficient approach to token vesting with clear visibility into vesting progress and available balances.