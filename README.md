# Sample Hardhat 3 Beta Project (`node:test` and `viem`)

This project showcases a Hardhat 3 Beta project using the native Node.js test runner (`node:test`) and the `viem` library for Ethereum interactions.

To learn more about the Hardhat 3 Beta, please visit the [Getting Started guide](https://hardhat.org/docs/getting-started#getting-started-with-hardhat-3). To share your feedback, join our [Hardhat 3 Beta](https://hardhat.org/hardhat3-beta-telegram-group) Telegram group or [open an issue](https://github.com/NomicFoundation/hardhat/issues/new) in our GitHub issue tracker.

## Project Overview

This example project includes:

- A simple Hardhat configuration file.
- Foundry-compatible Solidity unit tests.
- TypeScript integration tests using [`node:test`](nodejs.org/api/test.html), the new Node.js native test runner, and [`viem`](https://viem.sh/).
- Examples demonstrating how to connect to different types of networks, including locally simulating OP mainnet.

## Usage

### Running Tests

To run all the tests in the project, execute the following command:

```shell
npx hardhat test
```

You can also selectively run the Solidity or `node:test` tests:

```shell
npx hardhat test solidity
npx hardhat test nodejs
```

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

export PRIV_KEY=
export DEPLOYER=0xD58382f295f5c98BAeB525FAbb7FEBcCc62bc63B
export ZK_VERIFY=0xEA0A0f1EfB1088F4ff0Def03741Cb2C64F89361E
export USDC=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238

# --rpc-url http://127.0.0.1:8545 --broadcast 
export RPC_URL=
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIV_KEY 

forge verify-contract \
  --rpc-url https://sepolia.drpc.org \
  --verifier blockscout \
  --verifier-url 'https://eth-sepolia.blockscout.com/api/' \
  $LighterAccount \
  src/account/LighterAccount.sol:LighterAccount


forge test --match-path test/TakeIntent.t.sol --match-test testTakeSellerIntent -vvvvv


export LighterAccount=0xD18e648B1CBee795f100ca450cc13CcC6849Be64
export Escrow=0xe31527c75edc58343D702e3840a00c10c4858e25
export AllowanceHolder=0x302950de9b74202d74DF5e29dc2B19D491AE57a3
export TakenIntent=0x3DB826B7063bf8e51832B7350F7cbe359AEA3f60
export nostrSeller=0x2a9716cdd08bd7b14c94119c8259c89f3baab64d7b161eb03ad43dc1c1ccec68
export nostrBuyer=0x36bd5b22605899659cb1053737316096195b3ceb37c851645efd23e4497d7097



export PRIV_KEY=
export DEPLOYER=0xD58382f295f5c98BAeB525FAbb7FEBcCc62bc63B

cast send $LighterAccount 'createAccount(address,bytes32)' $DEPLOYER $nostrSeller --value 0.00001ether --private-key $PRIV_KEY
export seller=0x39246289fF8A80fFd396C401C1cA1864A89BCEfd
export buyer=0x4Ec864B529fA42A01488f363572429FEA573ed5D

export BUYER_PRIVATE_KEY=0x1688fea31b46a99193d45efa4a074740db943c0aee1334aaa8f2d86bb51705e8
export SELLER_PRIVATE_KEY=0x199b1a34d5cd548314842f6996456bb2a930c3763193dbe900192f993321ea43
export RELAYER_PRIVATE_KEY=0x199b1a34d5cd548314842f6996456bb2a930c3763193dbe900192f993321ea43
export BUYER_TBA=0x4Ec864B529fA42A01488f363572429FEA573ed5D
export SELLER_TBA=0x39246289fF8A80fFd396C401C1cA1864A89BCEfd
export USDC=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238

forge test --match-path test/TakeIntent.t.sol --match-test testTakeSellerIntent -vvvvv --ffi
