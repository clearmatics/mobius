const fs = require('fs');
const path = require('path');
var shellescape = require('shell-escape');
const { execSync } = require('child_process');
var bigInt = require("big-integer");
const defaultOrbitalBinPath = "/home/user/go/src/github.com/clearmatics/orbital/orbital";


const LinkableRing_tests = artifacts.require("./LinkableRing_tests.sol");
const Mixer = artifacts.require("./Mixer.sol");
const Mixer_tests = artifacts.require("./Mixer_tests.sol");
const bn256g1_tests = artifacts.require("./bn256g1_tests.sol");

const ringSignature = require("./ringSignature.bn256");

const inputDataDeposit = ringSignature.ring.map(d => [d.x, d.y]);
const inputDataWithdraw = ringSignature.signatures.map(d => [d.tau.x, d.tau.y, d.ctlist]);


/** Implements functionality similar to the 'which' command */
function which (name, defaultPath) {
    var X;
    try {
        X = execSync("/usr/bin/which " + name);
    }
    catch (err) {
        return defaultPath;
    }
    return X.trim("\n");
}


/** Filesystem path of the 'orbital' tool */
function findOrbital () {
    var foundWithWhich = which("orbital", defaultOrbitalBinPath);
    if( ! foundWithWhich || ! fs.existsSync(foundWithWhich) ) {
        return null;
    }
    return foundWithWhich;
}


const orbitalPath = findOrbital();

/** Execute `orbital` command, with array of arguments */
function orbital (args) {
    return execSync(shellescape([orbitalPath].concat(args)));
}


// XXX: truffle solidity tests are a lil broken due to the 'import' bug
// e.g. the imports in contracts/ are relative to the CWD not the source file
//      this means when compiling the tests the CWD is the project root, so 
//      conflicting paths...
const testContracts = {
    LinkableRing_tests: LinkableRing_tests,
    Mixer_tests: Mixer_tests,
    bn256g1_tests: bn256g1_tests
};
const allSimpleTests = {
    bn256g1_tests:  [
        "testOnCurve", "testHashToPoint", "testNegate", "testIdentity", "testEquality",
        "testOrder", "testModExp"
    ],
    LinkableRing_tests: [
        "testParticipate", "testVerify",
    ],
    Mixer_tests: [
        "testDeposit"
    ]
};
Object.keys(allSimpleTests).forEach(function(k) {
    var obj = testContracts[k];
    contract(k, (accounts) => {
        allSimpleTests[k].forEach(function (name) {
            it(name, (done) => {
                obj.deployed().then((instance) => {
                    const txObj = {from: accounts[0]};
                    instance[name].call(txObj).then(result => {
                        assert.ok(result, k + "." + name + " expected true!");
                        done();
                    });
                });
            });
        });
    });
});


contract('Mixer', (accounts) => {

});


// Only run these tests when the `Orbital` tool is present
if( orbitalPath ) {

}


// Random point on the alt_bn128 curve
function RandomPoint () {
    const P = bigInt("21888242871839275222246405745257275088696311157297823662689037894645226208583");
    const N = bigInt("21888242871839275222246405745257275088548364400416034343698204186575808495617");
    const A = bigInt("5472060717959818805561601436314318772174077789324455915672259473661306552146");
    while( true ) {
        const x = bigInt.randBetween(1, N.prev());
        const beta = x.multiply(x).mod(P).multiply(x).mod(P).add(3).mod(P);
        const y = beta.modPow(A, P);
        const y_squared = y.multiply(y).mod(P);
        if( y_squared.eq(beta) ) {
            return {x: x.toString(), y: y.toString()};
        }
    }
}


contract('Mixer', (accounts) => {
    it('Events and basic functionality', async () => {
        let instance = await Mixer.deployed();

        // Deposit 1 Wei into mixer
        const txValue = 1;
        const owner = accounts[0];
        const token = 0;            // 0 = ether
        const txObj = { from: owner, value: txValue };
        
        const startingBalance = web3.eth.getBalance(instance.address);
        const ringSize = 4;

        // Deposit 4 times (the ring size) into the mixer
        // Verify:
        //  - Mixer accepts deposits
        //  - Mixer emits MixerDeposit event for each deposit
        //  - Last deposit also emits MixerReady message
        var i = 0;
        var results = [];
        var ring_guid = null;
        while( i < (ringSize * 2) )
        {
            i += 1;
            const point = RandomPoint();
            let result = await instance.Deposit(token, txValue, point.x, point.y, txObj);
            assert.ok(result.receipt.status, "Bad deposit status");

            // Balance should increase by 1 Wei each deposit
            const contractBalance = web3.eth.getBalance(instance.address);
            assert.equal(contractBalance.toString(), startingBalance.add(txValue * i).toString());

            // MixerDeposit event should be triggered
            const expectedMixerReady = result.logs.some(el => (el.event === 'MixerDeposit'));
            assert.ok(expectedMixerReady, "MixerDeposit event was not emitted");

            // Ring GUID should match the previous one
            const readyEvent = result.logs.find(el => (el.event === 'MixerDeposit'));
            if( ring_guid !== null ) {
                assert.equal(readyEvent.args.ring_id, ring_guid, "Ring GUID batch doesn't match");
            }
            
            // For every N deposits, verify a MixerReady event has triggered
            const isLast = 0 == (i % ringSize);
            if( isLast ) {
                const expectedMixerReady = result.logs.some(el => (el.event === 'MixerReady'));
                assert.ok(expectedMixerReady, "MixerReady event was not emitted");
                ring_guid = null;
            }
        }
    });

    /*
    it('Deploy the contract', (done) => {
        Mixer.deployed().then((instance) => {     
            var availableForDeposit = instance.AvailableForDeposit({fromBlock: "latest"});
            assert.ok(availableForDeposit, 'Available for deposit event was not emitted');
           
            done();            
        });
    });
    */

    /*
    it('Starting the contract', (done) => {
        Mixer.deployed().then((instance) => {           
            const owner = accounts[0];
            const txObj = { from: owner };
            
            instance.start(txObj).then(result => {         
                const contractBalance = web3.eth.getBalance(instance.address).toString();
                
                const expectedRingMessage = result.logs.some(el => (el.event === 'RingMessage'));
                assert.ok(expectedRingMessage, "RingMessage event was not emitted"); 
                                           
                done();
            });
        });
    });
    */

    /*
    it('Deposit in ring and create particpants', (done) => {
        Mixer.deployed().then((instance) => {
            const depositValue = 1;
            const token = 0;            // 0 = ether
            const owner = accounts[0];
            const txValue = web3.toWei(depositValue, 'ether');
            const txObj = { from: owner, value: txValue };
            
            const txPromises = inputDataDeposit.reduce((prev, data) => {
                const pubPosX = data[0];
                const pubPosY = data[1];
                
                const executeDeposit = () => {
                    return instance.Deposit(token, depositValue, pubPosX, pubPosY, txObj)
                        .then(result => {
                            const txObj = web3.eth.getTransaction(result.tx);
                            const receiptStr = JSON.stringify(result,null,'\t');
                            const txStr = JSON.stringify(txObj,null,'\t');
                            return result;
                        });
                };
                return (prev ? prev.then(executeDeposit) : executeDeposit());
            }, undefined);
            txPromises.then((result) => {
                // TODO: verify that returned ring guid is the same for all transactions
                const expected = result.logs.some(el => (el.event === 'MixerDeposit'));
                assert.ok(expected, 'MixerDeposit event was not emitted');

                const contractBalance = web3.eth.getBalance(instance.address).toString();
                assert.deepEqual(contractBalance, web3.toWei(depositValue*inputDataDeposit.length, 'ether'));
                done();
            });
        });
    });
    */

    /*
    it('Withdraw from the ring', (done) => {
        Mixer.deployed().then((instance) => {
            const owner = accounts[0];
            const txObj = { from: owner, gas: 160000000 };
            
            const txPromises = inputDataWithdraw.reduce((prev, data) => {
                const pubPosX = data[0];
                const pubPosY = data[1];
                const signature = data[2]; // ctlist  
                              
                const executeWithdraw = () => {
                    return instance.withdraw(pubPosX, pubPosY, signature, txObj)
                        .then(result => {
                            const txObj = web3.eth.getTransaction(result.tx);
                            const receiptStr = JSON.stringify(result,null,'\t');
                            const txStr = JSON.stringify(txObj,null,'\t');
                            return result;
                        });
                };
                return (prev ? prev.then(executeWithdraw) : executeWithdraw());
            }, undefined);
            txPromises.then((result) => {
                const withdrawEventExpected = result.logs.some(el => (el.event === 'WithdrawEvent'));
                assert.ok(withdrawEventExpected, 'Withdraw event was not emitted');

                const availableForDepositExpected = result.logs.some(el => (el.event === 'AvailableForDeposit'));
                assert.ok(availableForDepositExpected, 'Available for deposit event was not emitted');

                const contractBalance = web3.eth.getBalance(instance.address).toString();
                assert.deepEqual(contractBalance, web3.toWei(0, 'ether'))
                done();
            });
        });
    });
    */
});
