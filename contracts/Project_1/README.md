# 1. Purchase NFT with ERC20 tokens

Build a classic NFT that can only be minted by paying with a particular ERC20 token.

## Solution
In short what i did was:
1. Create the ERC20 token contract
	- Import ERC20 openzeppelin contract.
	- Import Ownable openzeppelin contract. (this one is not strictly necessary)
2. Create the ERC721 token contract
	- Import IERC20 openzeppelin interface.
	- Import Ownable openzeppelin contract.
	- Import ERC721 openzeppelin contract.
	- Adding the following functions: mint(), setPrice(newPrice), withdraw(_to) and totalSupply()