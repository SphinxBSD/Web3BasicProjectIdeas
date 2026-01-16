# 3. NFT Swap Contract

Two people want to trade their NFTs in a trustless way. A user creates a swap on the contract, which is a pair of address, ids where the address is the smart contract address of the NFT and the id is the tokenId of the NFT. One person can deposit an NFT only if the id matches the address and id. The counterparty can deposit only if their NFT matches the address and id of the swap.

Once both are deposited, either party can call swap.

Some corner cases to think about:

    how long, if at all, should the traders be forced to keep their NFT in the contract?
