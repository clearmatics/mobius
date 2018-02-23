// Copyright (c) 2016-2017 Clearmatics Technologies Ltd

// SPDX-License-Identifier: LGPL-3.0+

const fs = require('fs');
const path = require('path');
const shellescape = require('shell-escape');
const { execSync } = require('child_process');
const tmp = require("tmp");
var JSONBigInt = require('json-bigint-string');

const Mixer = artifacts.require("./Mixer.sol");

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
            const inputs_txt = orbital(['inputs', '-f', keys_file.name, '-n', '4', '-m', ring_msg]);
            const inputs = JSON.parse(inputs_txt);

            // Verify signatures validate in orbital tool
            var inputs_file = await writeToTemp(inputs);
            const inputs_verified = orbital(['verify', '-f', inputs_file.name, '-m', ring_msg]);
            assert.equal(inputs_verified, "Signatures verified", "Orbital could not verify signatures");

            // Then perform all the withdraws
            var result = null;
            var total_gas = 0;
            var i = 0;
            for( var k in inputs.signatures ) {
                i++;

                // Verify the withdraw signature works
                const sig = inputs.signatures[k];
                const tau = sig.tau;
                const ctlist = sig.ctlist;
                result = await instance.Withdraw(ring_guid, tau.x, tau.y, ctlist);
                assert.ok(result.receipt.status, "Bad withdraw status");
                total_gas += result.receipt.gasUsed;

                // Verify same signature can't withdraw twice
                var ok = false;
                await instance.Withdraw(ring_guid, tau.x, tau.y, ctlist).catch(function(err) {
                    assert.include(err.message, 'revert', 'Withdraw twice should fail');
                    ok = true;
                });
                if( ! ok )
                    assert.fail("Duplicate withdraw didn't fail!");
            }

            console.log("      Average Gas per Withdraw: " + (total_gas / i));

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
