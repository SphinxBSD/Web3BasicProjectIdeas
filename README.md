# WEB3 BASIC PROJECT IDEAS

This project will contain the solutions for "Ten beginner project ideas after you learn Solidity" blog by [`rareskills`](https://rareskills.io/).

Link of the Blog: https://rareskills.io/post/beginner-solidity-projects

At the moment the repository has the following projects solved:
- Purchase NFT with ERC20 tokens
- Time unlocked ERC20 / vesting contract

## Installation

First clone the repository

```shell
git clone https://github.com/SphinxBSD/Web3BasicProjectIdeas.git
```

Install node dependencies
```shell
npm install
```

I used forge for testing the smart contracts, so if it was not installed with `npm install` execute the following command
```shell
npm add --save-dev "foundry-rs/forge-std#v1.11.0"
```

## Usage

### Running Tests

To run all the tests in the project, execute the following command:

```shell
npx hardhat test
```

You can also selectively run the Solidity(Highly recommended to run this) or `node:test` tests:

```shell
npx hardhat test solidity
npx hardhat test nodejs
```

If you want to test only one project, execute:
```shell
npx hardhat test solidity contracts/<Project folder>/<Test file>
```

## The following section is still incomplete so just ignore it for now

### Make a deployment to Sepolia

This project includes an example Ignition module to deploy the contract. You can deploy this module to a locally simulated chain or to Sepolia.

To run the deployment to a local chain:

```shell
npx hardhat ignition deploy ignition/modules/Counter.ts
```

To run the deployment to Sepolia, you need an account with funds to send the transaction. The provided Hardhat configuration includes a Configuration Variable called `SEPOLIA_PRIVATE_KEY`, which you can use to set the private key of the account you want to use.

You can set the `SEPOLIA_PRIVATE_KEY` variable using the `hardhat-keystore` plugin or by setting it as an environment variable.

To set the `SEPOLIA_PRIVATE_KEY` config variable using `hardhat-keystore`:

```shell
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
```

After setting the variable, you can run the deployment with the Sepolia network:

```shell
npx hardhat ignition deploy --network sepolia ignition/modules/Counter.ts
```
