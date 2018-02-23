// Copyright (c) 2016-2018 Clearmatics Technologies Ltd

// SPDX-License-Identifier: LGPL-3.0+

const fs = require('fs');
const path = require('path');
const shellescape = require('shell-escape');
const { execSync } = require('child_process');
const tmp = require("tmp");
const JSONBigInt = require('json-bigint-string');

const Mixer = artifacts.require("./Mixer.sol");

/** Implements functionality similar to the 'which' shell command */
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

/** Filesystem path of the 'orbital' command line tool */
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

/** Executes the "orbital generate" command with the number given as argument **/
function orbitalGenerateKeys (number) {
    return orbital(['generate', '-n', number.toString()]);
}

function getTimer() {
  return Date.now();
}

function getResult(timeMatrix, gasMatrix) {
  var depositAndCreateTimeArray = [];
  var depositAndCreateGasArray = [];
  var depositAndMixerReadyTimeArray = [];
  var depositAndMixerReadyGasArray = [];
  for (var i = 0; i < timeMatrix.length; i++) {
    depositAndCreateTimeArray.push(timeMatrix[i][0]);
    depositAndCreateGasArray.push(gasMatrix[i][0]);
    depositAndMixerReadyTimeArray.push(timeMatrix[i].pop());
    depositAndMixerReadyGasArray.push(gasMatrix[i].pop());
  }

  var depositOnlyTimeArray = [];
  var depositOnlyGasArray = [];

  var averageTimeDepositAndCreate = getAverage(depositAndCreateTimeArray);
  var averageTimeDepositAndMixerReady = getAverage(depositAndMixerReadyTimeArray);
  var averageTimeDepositOnly = getAverage(depositOnlyTimeArray);

  var averageGasDepositAndCreate = getAverage(depositAndCreateGasArray);
  var averageGasDepositAndMixerReady = getAverage(depositAndMixerReadyGasArray);
  var averageGasDepositOnly = getAverage(depositOnlyGasArray);

  // TODO: Write in a file instead of console.log()
  console.log("Number of Deposit done: " + numberOfDeposits);

  console.log("==== Stats of the first deposit to the mixer (which creates a ring of the specified denomination) ====");
  console.log("> Average Time: " + averageTimeDepositAndCreate + "ms");
  console.log("> Average Gas cost: " + averageGasDepositAndCreate + " gas\n");

  console.log("==== Stats of the last deposit to the mixer (which creates a mixer ready event) ====");
  console.log("> Average Time: " + averageTimeDepositAndMixerReady + "ms");
  console.log("> Average Gas cost: " + averageGasDepositAndMixerReady + " gas\n");

  console.log("==== Stats of a 'deposit only' ====");
  console.log("> Average Time: " + averageTimeDepositOnly + "ms");
  console.log("> Average Gas cost: " + averageGasDepositOnly + " gas\n");
}

contract('Mixer', (accounts) => {
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

    it('Benchmark: Average Performances of a Deposit to the Mixer', async () => {
        // Deposit 1 Wei into mixer
        const txValue = 1;
        const owner = accounts[0];
        const token = 0; // 0 = ether
        const txObj = { from: owner, value: txValue };

        // Analysis variables
        var timeMatrix = [];
        var gasMatrix = [];

        // Using the Truffle contract abstraction
        let instance = await Mixer.deployed();

        // The number of rings to fill during this benchmark
        var numberOfRings = 2;
        for (var i = 0; i < numberOfRings; i++) {

          // Generate as many keys as the size of the ring, to fill it entirely
          const ringSize = 10;
          var keys = JSONBigInt.parse(orbitalGenerateKeys(ringSize));

          // Record the time and gas measurments in arrays in order to do some advanced stats
          var timeArray = [];
          var gasCostArray = [];

          for (var k = 0; k < ringSize; k++) {
            const pubkey = keys.pubkeys[k];

            // Start the timer
            var timeBegin = getTimer();

            let result = await instance.Deposit(token, txValue, pubkey.x, pubkey.y, txObj);

            // End the timer
            var timeEnd = getTimer();

            var timeOfDeposit = timeEnd - timeBegin;
            var gasUsed = result.receipt.gasUsed;

            // Add the measurments to the arrays
            timeArray.push(timeOfDeposit);
            gasCostArray.push(gasUsed);

            const depositEvent = result.logs.find(el => (el.event === 'MixerDeposit'));
            if (depositEvent) {
              console.log("> Handled MixerDeposit Event");
            }
            const readyEvent = result.logs.find(el => (el.event === 'MixerReady'));
            if (readyEvent) {
              console.log("> Handled MixerReady Event ");
            }

            console.log("==== TIME taken: " + timeOfDeposit.toString() + "ms ====");
            console.log("==== GAS used: " + gasUsed.toString() + "gas ====\n");
          }

          // After a ring is filled (ie: all Deposit have been made), we analyze the data
          timeMatrix.push(timeArray);
          gasMatrix.push(gasCostArray);
        }

        // TODO: getResult(timeMatrix, gasMatrix);


        // Withdrawals
        //// Generate inputs from ring keys
        //const inputs_txt = orbital(['inputs', '-k', keys_file.name, '-n', '4', '-m', ring_msg]);
        //const inputs = JSON.parse(inputs_txt);

        //// Verify signatures validate in orbital tool
        //var inputs_file = await writeToTemp(inputs);
        //const inputs_verified = orbital(['verify', '-f', inputs_file.name, '-m', ring_msg]);
        //assert.equal(inputs_verified, "Signatures verified", "Orbital could not verify signatures");

        //// Then perform all the withdraws
        //var result = null;
        //var total_gas = 0;
        //var i = 0;
        //for( var k in inputs.signatures ) {
        //    i++;

        //    // Verify the withdraw signature works
        //    const sig = inputs.signatures[k];
        //    const tau = sig.tau;
        //    const ctlist = sig.ctlist;
        //    result = await instance.Withdraw(ring_guid, tau.x, tau.y, ctlist);
        //    console.log("Finished Withdrawal number " + i.toString());

        //    const withdrawEvent = result.logs.find(el => (el.event === 'MixerWithdraw'));
        //    if (withdrawEvent) { console.log("Withdraw Event"); }
        //    assert.ok(result.receipt.status, "Bad withdraw status");
        //    total_gas += result.receipt.gasUsed;

        //    // Verify same signature can't withdraw twice
        //    var ok = false;
        //    await instance.Withdraw(ring_guid, tau.x, tau.y, ctlist).catch(function(err) {
        //        assert.include(err.message, 'revert', 'Withdraw twice should fail');
        //        ok = true;
        //    });
        //    if( ! ok )
        //        assert.fail("Duplicate withdraw didn't fail!");
        //}

        //console.log("      Average Gas per Withdraw: " + (total_gas / i));

        //// Verify the Ring is dead
        //const expectedMixerDead = result.logs.some(el => (el.event === 'MixerDead'));
        //assert.ok(expectedMixerDead, "Last Withdraw should emit MixerDead event");
        //const deadEvent = result.logs.find(el => (el.event === 'MixerDead'));
        //assert.equal(deadEvent.args.ring_id.toString(), ring_guid, "Ring GUID batch doesn't match in MixerDead");

        //// And that all money has been withdrawn
        //const finishBalance = web3.eth.getBalance(instance.address);
        //assert.equal(finishBalance.toString(), initialBalance.toString(), "Finish balance should be same as initial balance");

        //inputs_file.removeCallback();
        //keys_file.removeCallback();

    });
});
