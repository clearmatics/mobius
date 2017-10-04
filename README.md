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
    yarn truffle

This will compile the contract, deploy to the testrpc instance and run the tests. 

[1]: https://eprint.iacr.org/2017/881.pdf
[2]: http://truffleframework.com/
[3]: https://nodejs.org/
[4]: https://yarnpkg.com/en/docs/install
[5]: https://docs.npmjs.com/getting-started/installing-node
