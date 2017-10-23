# Example data for Möbius

The example data is for evaluation purposes only. Do not use this data for real contracts. 

The `example.json` file contains example data for a Möbius contract with a ring size of 4. The Hex encoded string used for this was `8a0f11e78d5cc231652a03e89ec242edb2811b45d2a1169d9eab7d473a28915d`.

The data was generated using the orbital tool with the following command

    orbital -geninputs 4 8a0f11e78d5cc231652a03e89ec242edb2811b45d2a1169d9eab7d473a28915d

A Möbius contract should be deployed with two arguments. The first represents the size of the ring and the second is the denomination of the ring. The arguments `4` and `1` declare a ring size of 4 and a denomination of 1. 

## Depositing into a contract

Deposits are made using the `deposit` function.

A deposit uses the public key `x` and `y` coordinates along with a value to be paid. Since the payee for the contract is identified through the corresponding private no identity for the payee needs to given to the contract.

## Withdrawing from a contract

Deposits are made using the `withdraw` function.

To withdraw from the contract a signature needs to be generated off-chain using the public and private keys for a transaction. A withdrawal can only be made once the ring is full and corresponds to a single deposit. The example data contains an array of public key `x` and `y` coordinates. The corresponding signature is also included in this file and the signature matches the public key at the same position in the array. 

Assuming the example data has been parsed and assigned to a variable `ringJSON` the following is a public key coordinate pair.

    ringJSON.ring[0]

This has the matching signature

    ringJSON.signatures[0]

To deposit use the public key coordinate pair data, to withdraw use the matching signature data. 
