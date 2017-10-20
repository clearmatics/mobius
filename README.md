# Möbius

Trustless Tumbling for Transaction Privacy

## White Paper

[https://eprint.iacr.org/2017/881.pdf][1]


## Developing

[Truffle][2] is used to develop and test the Mobius Smart Contract. This has a dependency of [Node.js][3].

Pre-requirements:

[yarn][4] needs to be installed (but [npm][5] should work just as well).

    yarn install

This will install all the required packages.

Start `testrpc` in a separate terminal tab or window.

    yarn testrpc
    
    # in separate window or tab
    yarn test

#### Create new test data

The [orbital][6] tool is needed to generate the signatures and random keys for the tests

    # generate random key pairs
    ./orbital -genkeys 4 > keys.json 

    # generate ring signatures
    ./orbital -signature keys.json 50b44f86159783db5092ebe77fb4b9cc29e445e54db17f0e8d2bed4eb63126fc > ringSignature.json

    # verify if the signatures are correct
    ./orbital -verify ringSignature.json 50b44f86159783db5092ebe77fb4b9cc29e445e54db17f0e8d2bed4eb63126fc

After generating the signatures overwrite the [ringSignatures.json](test/ringSignatures.json) with the new ring signatures.


This will compile the contract, deploy to the testrpc instance and run the tests. 

[1]: https://eprint.iacr.org/2017/881.pdf
[2]: http://truffleframework.com/
[3]: https://nodejs.org/
[4]: https://yarnpkg.com/en/docs/install
[5]: https://docs.npmjs.com/getting-started/installing-node
[6]: https://gitlab.clearmatics.net/oss/orbital
