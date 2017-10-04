# Möbius

Trustless Tumbling for Transaction Privacy

## White Paper

[https://eprint.iacr.org/2017/881.pdf][1]


## Developing

[Truffle][2] is used to develop and test the Mobius Smart Contract. This has a dependency of [Node.js][3].

    npm install -g truffle ethereumjs-testrpc

Start `testrpc` in a separate terminal tab or window.

    testrpc
    
    # in separate window or tab
    truffle test

This will compile the contract, deploy to the testrpc instance and run the tests. 

[1]: https://eprint.iacr.org/2017/881.pdf
[2]: http://truffleframework.com/
[3]: https://nodejs.org/
