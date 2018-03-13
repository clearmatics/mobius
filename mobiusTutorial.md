# Sending transactions with Mobius

## Environment

- Truffle:
```bash
$ truffle version
Truffle v4.1.0 (core: 4.1.0)
Solidity v0.4.19 (solc-js)
```

- Geth:
```bash
$ geth version
Geth
Version: 1.8.1-stable
Git Commit: 1e67410e88d2685bc54611a7c9f75c327b553ccc
```

- Npm:
```bash
$ npm --version
5.6.0
```

- Node:
```bash
$ node --version
v9.5.0
```

## How to use Mobius ?

---------------------------------------------------

As Möbius supports transfer of ethers and ERC20 compatible tokens, we denote by `Deposit` and `Withdraw` - in this tutorial - the action to do a deposit and a withdrawal to and from the Mixer. The user is free to use the appropriate suffix `Ether` or `ERC20Compatible`.

:warning: In order for the `DepositERC20Compatible` function to run, the sender has to authorize the `Mixer` to trigger a transfer of tokens on his behalf, **FIRST**. To do this, the sender has to run: `token.approve([mixerAddress], [amountToApprove], {from: [senderAccount]});` (see: ERC20 interface for more details), before calling `DepositERC20Compatible`.

:warning: The `DepositERC20Compatible` function is not payable, so the `value` field of the transaction object should be omitted.

---------------------------------------------------

### Assumptions

1. The `Mixer` has a `RING_SIZE` equal to 1 (see: https://github.com/clearmatics/mobius/blob/master/contracts/LinkableRing.sol#L80).
If you want to follow the rest of the tutorial, please clone this repository and modify the `LinkableRing` contract accordingly:
```bash
export $WORKDIR = ~/Path/To/Your/Working/Directory
git clone https://github.com/clearmatics/mobius.git $WORKDIR
cd $WORKDIR/mobius
[YourFavoriteTextEditor] contracts/LinkableRing.sol
[Change line 80: uint256 public constant RING_SIZE = 4; INTO uint256 public constant RING_SIZE = 1;]
[Save and exit your editor]
```
2. We call Alice the sender of the payment and Bob the recipient.
3. We assume that two accounts with some ethers are available in order to run this tutorial.

### Step 1: Generate a master key pair for Bob, using Orbital

__Orbital:__ https://github.com/clearmatics/orbital

1. Run `orbital generate -n 1 > keys.json && cat keys.json`:
```javascript
{
    "pubkeys": [
        {
            "x": "0x26569781c3ab69ff42834ea67be539bb231fa48730afc3c89f2bba140b2045b2",
            "y": "0xbf75913861d38b5a01b53654daa260856d5dd705af6a24e57622811d485e407"
        }
    ],
    "privkeys": [
        "0x216e142880261d4b743386185c41ae9cf3609f648dbedc15bd0790332b23fb87"
    ]
}
```

### Step 2: Compile and deploy the Mobius Contracts to your network

:warning: **WARNING**: Mobius is not ready to use in production. It should only be used for a testing/prototyping purpose ! :warning:

#### Start your ethereum client

##### Method 1: Use Ganache-cli (testrpc)

1. Make sure you have Ganache-cli installed
```bash
Ganache CLI v6.0.3 (ganache-core: 2.0.2)
```
2. Start Ganache-cli:
```bash
yarn testrpc
```

##### Method 2: Use your own local Geth private environment

The steps described in this section should only be executed if you decided not to use `Ganache-cli` to run Mobius.

1. Create a `genesis.json` file like this one: `touch genesis.json` and copy paste the code below into your `genesis.json` file:
```javascript
{
    "config": {
        "chainId": 127,
            "homesteadBlock": 0,
            "eip155Block": 0,
            "eip158Block": 0,
            "byzantiumBlock": 0
    },
    "alloc"      : {
        "0x557ef97e60a4aab92c3b3e000a67fb5d26be04b4": {
            "balance": "10000000000000000000000000000000000000000000000000000"
        },
        "0x8a7cf916f9b6e1bb77ea6282eb5c8b5eb5b779cc": {
            "balance": "10000000000000"
        },
    },
    "coinbase"   : "0x0000000000000000000000000000000000000000",
    "difficulty" : "0x20000",
    "extraData"  : "",
    "gasLimit"   : "0xFFFFFFF",
    "gasPrice"   : "0x1",
    "nonce"      : "0x0000000000000042",
    "mixhash"    : "0x0000000000000000000000000000000000000000000000000000000000000000",
    "parentHash" : "0x0000000000000000000000000000000000000000000000000000000000000000",
    "timestamp"  : "0x00"
}
```
*Note:* Make sure to have the line `"byzantiumBlock": 0` in the `config` of your `genesis.json` file in order to make sure that the Mobius contract will be able to execute precompiled contracts. (See: [Byzantium](https://blog.ethereum.org/2017/10/12/byzantium-hf-announcement/))
2. Create the data directory for your local configuration of your ethereum network:
```bash
mkdir ~/ethdev
```
3. Start your node with the genesis configuration:
```bash
geth --datadir ~/ethdev init genesis.json
```
4. Start your mining node and open the geth console:
```bash
geth --datadir ~/ethdev --identity=NODE_ONE --networkid=15 --verbosity=1 --mine --minerthreads=1 --rpc --rpcport=8545 --nodiscover --maxpeers=1 console
```

All the steps above are gathered into a script below. Run: `touch startCustomNode.sh && chmod +x startCustomNode.sh` and Copy/Paste the content below into the file, then run: `./startCustomNode.sh`
```bash
#!/bin/bash

if [ ! -f "./geth" ]; then 
    echo "==> Fetching GETH 1.8.1 <==\n"
    wget https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.8.1-1e67410e.tar.gz
    echo "Unpacking GETH 1.8.1"
    tar -xvf geth-linux-amd64-1.8.1-1e67410e.tar.gz
fi

echo "==> Creating ~/ethdev folder <== \n"
mkdir ~/ethdev

echo "==> Initializing the private blockchain with custom genesis file <==\n"
./geth --datadir ~/ethdev init genesis.json

echo "==> Starting miner node: Listening rpc on 8545 <==\n"
./geth --datadir ~/ethdev --identity=NODE_ONE --networkid=15 --verbosity=1 --mine --minerthreads=1 --rpc --rpcport=8545 --nodiscover --maxpeers=1 console
```

#### Deploy the Mobius contracts:

##### Method 1 (Easy way): Using truffle

1. Compile the contracts:
```bash
truffle compile
```
2. Deploy the contracts to the `development` network
```bash
truffle deploy --network development
```
The logs of truffle deploy should output the address to which the Mixer has been deployed `Mixer: [Address]`. If you can't see this log, run `Mixer.deployed()` in the `truffle console` and save the address somewhere (we'll need it in a few steps).
3. Get the Mixer Abi:
```bash
echo "var MixerAbi=`solc --optimize --combined-json abi contracts/Mixer.sol`" > mixerAbi.js
```

*In the Geth console, run the following commands*

1. Load the file containing the ABI of the Mixer contract:
```bash
loadScript('mixerAbi.js')
```
2. Store the ABI of the Mixer into a variable:
```bash
var mixerContractAbi = MixerAbi.contracts['contracts/Mixer.sol:Mixer'].abi;
```
3. Run:
```bash
var mixerContract = eth.contract(JSON.parse(mixerContractAbi));
var mixerContractAddress = [Paste here the Mixe Address saved at step 2];
var mixer = mixerContract.at(mixerContractAddress);
```
After this step, we can use the `mixerInstance` variable in order to interact with the contract from the geth console.

##### Method 2 ("Hard way"): Manual deployment in Geth

1. Compile the Mixer contract:
```bash
echo "var mixerOutput=`solc --optimize --combined-json abi,bin,interface contracts/Mixer.sol`" > mixer.js
```

*In the Geth console, run the following commands*

1. Load the `mixer.js` file:
```bash
loadScript('mixer.js')
```
2. Store the ABI of the Mixer into a variable:
```bash
var mixerContractAbi = mixerOutput.contracts['contracts/Mixer.sol:Mixer'].abi
```
3. Run:
```bash
var mixerContract = eth.contract(JSON.parse(mixerContractAbi))
var mixerBinCode = "0x" + mixerOutput.contracts['contracts/Mixer.sol:Mixer'].bin
personal.unlockAccount([AccountYouWantToUseToDeploy], [PasswordOfTheAccount], 0)
var deployTransationObject = { from: eth.accounts[0], data: mixerBinCode, gas: 1000000 };
var mixerInstance = mixerContract.new(deployTransationObject)
var mixerContractAdress = eth.getTransactionReceipt(mixerInstance.transactionHash).contractAddress
var mixer = mixerContract.at(mixerContractAddress);
```

### Step 3: Interact with Mobius and proceed to payments

1. Define listeners to listen to the Mixer events:
```javascript
var mixerDepositEvent = mixer.MixerDeposit();
mixerReadyEvent.watch(function(error, result){
    if (error) { console.log(error); return; }
    console.log("MixerDeposit event");
});

var mixerReadyEvent = mixer.MixerReady();
mixerReadyEvent.watch(function(error, result){
    if (error) { console.log(error); return; }
    console.log("MixerReady event");
    console.log("Ring message: " + result.args.message); 
    console.log("Ring GUID: " + result.args.ring_id); 
});

var mixerWithdrawEvent = mixer.MixerWithdraw();
mixerWithdrawEvent.watch(function(error, result){
    if (error) { console.log(error); return; }
    console.log("MixerWithdraw event"); 
});

var mixerDeadEvent = mixer.MixerDead();
mixerDeadEvent.watch(function(error, result){
    if (error) { console.log(error); return; }
    console.log("MixerDead event"); 
});
```
2. Get the balance of the Mixer (should be equal to zero):
```bash
eth.getBalance("[mixerAddress]")
```
3. Deposit funds to the Mixer:
```bash
var pubX = [X component of pubKey in keys.json]
var pubY = [Y component of pubKey in keys.json]

var AliceAccount = eth.accounts[0];
var gasValue: [AmountOfGasAliceIsReadyToPay]
var yourDenomination = [AmountOfMoneyYouWantToTransfer]

// We trigger a deposit from Alice's account
mixer.Deposit(0, yourDenomination, pubX, pubY, {from: AliceAccount, value: yourDenomination, gas: gasValue})
```
4. Verify that the deposit has successfully been done on the contract (the balance of the contract should be equal to the denomination)specified by the sender in the `Deposit` function
```bash
eth.getBalance("[mixerAddress]")
```
5. Generate the ring signature using orbital:
```bash
orbital inputs -n 1 -f keys.json -m [RingMessage] > signature.json
```
6. Withdraw funds from Bob's account:
```bash
var bobAccount = eth.accounts[1];
personal.unlockAccount(bobAccount); // Unlock Bob's account

var tauX = [tauX in signature.json];
var tauY = [tauY in signature.json];
var ctlist = [ctlistArray]

var ringGuid = [ring GUID returned by the mixerReadyEvent];

var gasValue: [AmountOfGasBobIsReadyToPay]

mixer.Withdraw(ringGuid, tauX, tauY, ctlist, {from: bobAccount, gas: gasValue});
```

### Step 4: Verify that the payment worked

1. At this stage of the process, the balance of the Mixer should be equal to 0 again. Verify it:
```
eth.getBalance("[mixerAddress]")
```
2. Bob's account should have been credited. In order to make sure that everything worked well, Bob's balance after the withdrawal should respect the equality:
```
BalanceAfterWithdrawal = (BalanceBeforeWithdrawal - (gasUsed * gasPrice)) + denomination
```
_Note:_ The `gasUsed` and `gasPrice` values can be accessed directly by running `eth.getTransactionReceipt("[HashOfTheWithdrawalTX]")`.
## Observed Caveat
- Bob has to have funds on his account in order to be able to pay for the Withdraw function to be executed. Thus, Mobius cannot be used to send funds to an address that doesn't have a minimum amount of funds.
