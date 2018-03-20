// Copyright (c) 2016-2018 Clearmatics Technologies Ltd

// SPDX-License-Identifier: LGPL-3.0+

const bigInt = require("big-integer");
var JSONBigInt = require('json-bigint-string');

const LinkableRing_tests = artifacts.require("./LinkableRing_tests.sol");
const Mixer = artifacts.require("./Mixer.sol");
const bn256g1_tests = artifacts.require("./bn256g1_tests.sol");

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
      "testIsOnCurve",
      "testHashToPoint",
      "testNegate",
      "testIdentity",
      "testEquality",
      "testOrder",
      "testModExp"
    ],
    LinkableRing_tests: [
      "testInit",
      "testVerify",
      "testParticipate"
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

function CreateDummyTx(account, value) {
    return { from: account, value: value };
}

contract('Mixer', (accounts) => {
    it('Invalid and duplicate deposits', async () => {
        var point = RandomPoint();

        const txObj = CreateDummyTx(accounts[0], 1);
        const token = 0;            // 0 = ether

        let instance = await Mixer.deployed();

        // This should succeed
        let result = await instance.depositEther(token, txObj.value, point.x, point.y, txObj);
        assert.ok(result.receipt.status, "Bad deposit status with valid point");

        // This will fail because the point is already in a ring
        var ok = false;
        result = await instance.depositEther(token, txObj.value, point.x, point.y, txObj).catch(function(err) {
            assert.include(err.message, 'revert', 'Deposit with duplicate key should revert');
            ok = true;
        });
        if(!ok) {
          assert.fail("Deposit with duplicate key should revert");
        }

        // This will fail because the point is invalid
        point = RandomPoint();
        ok = false;
        result = await instance.depositEther(token, txObj.value, 123, point.y, txObj).catch(function(err) {
            assert.include(err.message, 'revert', 'Deposit with invalid point should revert');
            ok = true;
        });
        if(!ok) {
            assert.fail("Deposit with invalid point should have reverted!");
        }

        // This will fail because the denomination is invalid
        ok = false;
        result = await instance.depositEther(token, 0, point.x, point.y, txObj).catch(function(err) {
            assert.include(err.message, 'revert', 'Deposit with invalid denomination should revert');
            ok = true;
        });
        if(!ok) {
            assert.fail("Deposit with invalid denomination should revert");
        }

        // Then fill the ring with a remaining 3, otherwise further tests will fail
        for( var i = 0; i < 3; i++ ) {
            point = RandomPoint();
            result = await instance.depositEther(token, txObj.value, point.x, point.y, txObj);
        }
    });

    it('Events and basic functionality', async () => {
        let instance = await Mixer.deployed();

        // Deposit 1 Wei into mixer
        const txValue = 1;
        const owner = accounts[0];
        const token = 0;            // 0 = ether
        const txObj = { from: owner, value: txValue };
        const startingBalance = web3.eth.getBalance(instance.address);
        const ringSize = 4;
        const logDepositEvent = 'LogMixerDeposit';
        const logReadyEvent = 'LogMixerReady';

        // Deposit 4 times (the ring size) into the mixer
        // Verify:
        //  - Mixer accepts deposits
        //  - Mixer emits LogMixerDeposit event for each deposit
        //  - Last deposit also emits MixerReady message
        var i = 0;
        var results = [];
        var ring_guid = null;
        var total_gas = 0;
        while(i < (ringSize * 2)) {
            i++;
            // Deposit a random public key
            const point = RandomPoint();
            let result = await instance.depositEther(token, txValue, point.x, point.y, txObj);
            assert.ok(result.receipt.status, "Bad deposit status");
            total_gas += result.receipt.gasUsed;

            // Balance should increase by 1 Wei each deposit
            const contractBalance = web3.eth.getBalance(instance.address);
            assert.equal(contractBalance.toString(), startingBalance.add(txValue * i).toString());

            // A deposit event should be triggered
            const expectedMixerDeposit = result.logs.some(el => (el.event === logDepositEvent));
            assert.ok(expectedMixerDeposit, "Deposit event was not emitted");

            // Ring GUID should match the previous one
            const depositEvent = result.logs.find(el => (el.event === logDepositEvent));
            if( ring_guid !== null ) {
                assert.equal(depositEvent.args.ring_id.toString(), ring_guid, "Ring GUID batch doesn't match");
            }
            else {
                ring_guid = depositEvent.args.ring_id.toString();
            }

            // For every N deposits, verify a ready event has triggered
            const isLast = 0 == (i % ringSize);
            if( isLast ) {
                const expectedMixerReady = result.logs.some(el => (el.event === logReadyEvent));
                assert.ok(expectedMixerReady, "Ready event was not emitted");

                const readyEvent = result.logs.find(el => (el.event === logReadyEvent));
                assert.equal(readyEvent.args.ring_id, ring_guid, "Ring GUID batch doesn't match");

                ring_guid = null;
            }
        }
        console.log("\tAverage Gas per Deposit: " + (total_gas / i));
    });
});
