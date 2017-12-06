const fs = require('fs');
const path = require('path');
const shellescape = require('shell-escape');
const { execSync } = require('child_process');
const bigInt = require("big-integer");
const tmp = require("tmp");
var JSONBigInt = require('json-bigint-string');


const LinkableRing_tests = artifacts.require("./LinkableRing_tests.sol");
const Mixer = artifacts.require("./Mixer.sol");
const bn256g1_tests = artifacts.require("./bn256g1_tests.sol");

const ringSignature = require("./ringSignature.bn256");

const inputDataDeposit = ringSignature.ring.map(d => [d.x, d.y]);
const inputDataWithdraw = ringSignature.signatures.map(d => [d.tau.x, d.tau.y, d.ctlist]);


/** Implements functionality similar to the 'which' command */
function which (name, defaultPath) {
    var X;
    try {
        X = execSync("/usr/bin/which " + name).toString();
    }
    catch (err) {
        return defaultPath;
    }
    return X.trim("\n");
}


/** Filesystem path of the 'orbital' tool */
const defaultOrbitalBinPath = "/home/user/go/src/github.com/clearmatics/orbital/orbital";
function findOrbital () {
    var foundWithWhich = which("orbital", defaultOrbitalBinPath);
    if( ! foundWithWhich || ! fs.existsSync(foundWithWhich) ) {
        return null;
    }
    return foundWithWhich;
}


/** Execute `orbital` command, with array of arguments */
const orbitalPath = findOrbital();
function orbital (args) {
    return execSync(shellescape([orbitalPath].concat(args))).toString().trim("\n");
}


// XXX: truffle solidity tests are a lil broken due to the 'import' bug
// e.g. the imports in contracts/ are relative to the CWD not the source file
//      this means when compiling the tests the CWD is the project root, so 
//      conflicting paths...
const testContracts = {
    LinkableRing_tests: LinkableRing_tests,
    bn256g1_tests: bn256g1_tests
};
const allSimpleTests = {
    bn256g1_tests:  [
        "testOnCurve", "testHashToPoint", "testNegate", "testIdentity", "testEquality",
        "testOrder", "testModExp"
    ],
    LinkableRing_tests: [
        "testInit", "testParticipate", "testVerify",
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
        while( i++ < (ringSize * 2) )
        {
            // Deposit a random public key
            const point = RandomPoint();
            let result = await instance.Deposit(token, txValue, point.x, point.y, txObj);
            assert.ok(result.receipt.status, "Bad deposit status");

            // Balance should increase by 1 Wei each deposit
            const contractBalance = web3.eth.getBalance(instance.address);
            assert.equal(contractBalance.toString(), startingBalance.add(txValue * i).toString());

            // MixerDeposit event should be triggered
            const expectedMixerDeposit = result.logs.some(el => (el.event === 'MixerDeposit'));
            assert.ok(expectedMixerDeposit, "MixerDeposit event was not emitted");

            // Ring GUID should match the previous one
            const depositEvent = result.logs.find(el => (el.event === 'MixerDeposit'));
            if( ring_guid !== null ) {
                assert.equal(depositEvent.args.ring_id.toString(), ring_guid, "Ring GUID batch doesn't match");
            }
            else {
                ring_guid = depositEvent.args.ring_id.toString();
            }
            
            // For every N deposits, verify a MixerReady event has triggered
            const isLast = 0 == (i % ringSize);
            if( isLast ) {
                const expectedMixerReady = result.logs.some(el => (el.event === 'MixerReady'));
                assert.ok(expectedMixerReady, "MixerReady event was not emitted");

                const readyEvent = result.logs.find(el => (el.event === 'MixerReady'));
                assert.equal(readyEvent.args.ring_id, ring_guid, "Ring GUID batch doesn't match");

                ring_guid = null;
            }
        }
    });
});


// Only run these integration tests when the `orbital` tool is present
if( orbitalPath ) {
    async function writeToTemp(data) {
        var tmp_file = tmp.fileSync();
        await new Promise((resolve, reject) => {
            fs.write(tmp_file.fd, JSON.stringify(data), (err) => {
                if( err )
                    reject(err);
                else {
                    resolve();
                }
            });
        });
        return tmp_file;
    }

    contract('Mixer', (accounts) => {
        it('Integrates with Orbital', async () => {
            // Generate 4 keys
            const keys_txt = orbital(['generate', '-n', '4']);
            const keys = JSONBigInt.parse(keys_txt);
            var keys_file = await writeToTemp(keys);

            // Deposit 1 Wei into mixer
            const txValue = 1;
            const owner = accounts[0];
            const token = 0;            // 0 = ether
            const txObj = { from: owner, value: txValue };

            let instance = await Mixer.deployed();
            const initialBalance = web3.eth.getBalance(instance.address);

            // For each key in inputs, deposit into the Ring
            var ring_msg = null;
            var ring_guid = null;
            var k = 0;
            for( var j in keys.pubkeys ) {
                const pubkey = keys.pubkeys[j];
                k++;

                let result = await instance.Deposit(token, txValue, pubkey.x, pubkey.y, txObj);
                assert.ok(result.receipt.status, "Bad deposit status");

                const depositEvent = result.logs.find(el => (el.event === 'MixerDeposit'));
                ring_guid = depositEvent.args.ring_id.toString();

                const readyEvent = result.logs.find(el => (el.event === 'MixerReady'));
                if( readyEvent ) {
                    ring_msg = readyEvent.args.message.toString().substr(2);
                }
            }

            // Contract balance should have increased to equal the N deposits
            const contractBalance = web3.eth.getBalance(instance.address);
            assert.equal(contractBalance.toString(), initialBalance.add(txValue * k).toString());

            // Generate inputs from ring keys
            const inputs_txt = orbital(['inputs', '-k', keys_file.name, '-n', '4', '-m', ring_msg]);
            const inputs = JSON.parse(inputs_txt);

            // Verify signatures validate in orbital tool
            var inputs_file = await writeToTemp(inputs);
            const inputs_verified = orbital(['verify', '-f', inputs_file.name, '-m', ring_msg]);
            assert.equal(inputs_verified, "Signatures verified", "Orbital could not verify signatures");

            // Then perform all the withdraws
            var result = null;
            for( var k in inputs.signatures ) {
                const sig = inputs.signatures[k];
                const tau = sig.tau;
                const ctlist = sig.ctlist;
                result = await instance.Withdraw(ring_guid, tau.x, tau.y, ctlist)
            }

            // Verify the Ring is dead
            const expectedMixerDead = result.logs.some(el => (el.event === 'MixerDead'));
            assert.ok(expectedMixerDead, "Last Withdraw should emit MixerDead event");
            const deadEvent = result.logs.find(el => (el.event === 'MixerDead'));
            assert.equal(deadEvent.args.ring_id.toString(), ring_guid, "Ring GUID batch doesn't match in MixerDead");

            // And that all money has been withdrawn
            const finishBalance = web3.eth.getBalance(instance.address);
            assert.equal(finishBalance.toString(), initialBalance.toString(), "Finish balance should be same as initial balance");

            inputs_file.removeCallback();
            keys_file.removeCallback();
        });
    });
}
