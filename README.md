# Möbius

Trustless Tumbling for Transaction Privacy

## Introduction

Möbius is a Smart Contract that runs on Ethereum that offers trustless tumbling. The contract uses `secp256k1` and is applicable to private networks, due to the gas cost of running the contract. The contract will be ported to use `alt_bn128` making it applicable to the public network.

## White Paper

[S. Meiklejon, R. Mercer. Möbius: Trustless Tumbling for Transaction Privacy][1]

## Using Möbius

To generate data for a Möbius contract the [Orbital][6] tool is provided. Installation details are available in the Orbital repository.

The `orbital` CLI tool supports the generation of data to create a `mobius` contract and to deposit and withdraw. 

Möbius contracts are deployed in the standard way and declare the size of a ring and the denomination of the deposit.

## Developing

[Truffle][2] is used to develop and test the Möbius Smart Contract. This has a dependency of [Node.js][3]. [solidity-coverage ][7] provides code coverage metrics. 

Prerequisites:

[yarn][4] needs to be installed (but [npm][5] should work just as well).

    yarn install

This will install all the required packages.

Start `testrpc` in a separate terminal tab or window.

    yarn testrpc
    
    # in separate window or tab
    yarn test

This will compile the contract, deploy to the Ganache instance and run the tests. 

#### Testing with Orbital

The [orbital][6] tool is needed to generate the signatures and random keys for some of the tests. If `orbital` is in `$PATH` the `yarn test` command will run additional tests which verify the functionality of the Mixer contract using randomly generated keys instead of the fixed test cases.

[1]: https://eprint.iacr.org/2017/881.pdf
[2]: http://truffleframework.com/
[3]: https://nodejs.org/
[4]: https://yarnpkg.com/en/docs/install
[5]: https://docs.npmjs.com/getting-started/installing-node
[6]: https://github.com/clearmatics/orbital
[7]: https://www.npmjs.com/package/solidity-coverage
