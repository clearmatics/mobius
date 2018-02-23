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

async function generateAndVerifySignature(keys, ringMsg) {
    var keys_file = await writeToTemp(keys);
    const inputs_txt = orbital(['inputs', '-k', keys_file.name, '-n', '4', '-m', ringMsg.substr(2)]);
    const inputs = JSON.parse(inputs_txt);

    // Verify signatures validate in orbital tool
    var inputs_file = await writeToTemp(inputs);
    const inputs_verified = orbital(['verify', '-f', inputs_file.name, '-m', ringMsg.substr(2)]);
    assert.equal(inputs_verified, "Signatures verified", "Orbital could not verify signatures");

    return inputs;
}

function getTime() {
  return Date.now();
}

/** Computes the average values of an array **/
function getAverage(values) {
    assert(typeof(values) === typeof([]));

    var itemsNo = values.length;
    var sum = 0;

    for (var i in values) {
        sum += values[i];
    }

    return parseInt(sum/itemsNo);
}

function parseDepositBenchmarkResults(ringResult) {
    console.log("\n==========================================================")
    console.log("\n======= Starting deposit benchmark result analysis =======\n");
    console.log("==========================================================\n");

    var depositAndCreateTimeArray = [];
    var depositAndCreateGasArray = [];

    var depositOnlyTimeArray = [];
    var depositOnlyGasArray = [];

    var depositAndMixerReadyTimeArray = [];
    var depositAndMixerReadyGasArray = [];

    var numberOfDeposits = 0;

    for (var i in ringResult) {
        var data = ringResult[i];
        numberOfDeposits += data.time.length;

        depositAndCreateTimeArray.push(data.time[0]);
        depositAndCreateGasArray.push(data.gas[0]);

        depositAndMixerReadyTimeArray.push(data.time.pop());
        depositAndMixerReadyGasArray.push(data.gas.pop());

        depositOnlyTimeArray.push.apply(depositOnlyTimeArray, data.time.slice(1, data.time.length));
        depositOnlyGasArray.push.apply(depositOnlyGasArray, data.gas.slice(1, data.gas.length));
    }

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

function parseWithdrawBenchmarkResults(ringResult) {
    console.log("\n=============================================================")
    console.log("\n======= Starting withdrawal benchmark result analysis =======\n")
    console.log("=============================================================\n")

    var numberOfWithdrawals = 0;

    var withdrawalTimes = [];
    var withdrawalGas = [];

    for (var i in ringResult) {
        var data = ringResult[i];
        numberOfWithdrawals += data.time.length;

        withdrawalTimes.push.apply(withdrawalTimes, data.time);
        withdrawalGas.push.apply(withdrawalGas, data.gas);
    }

    var averageWithdrawalTime = getAverage(withdrawalTimes);
    var averageWithdrawalGas = getAverage(withdrawalGas);

    // TODO: Write in a file instead of console.log()
    console.log("Number of Withdrawals done: " + numberOfWithdrawals);

    console.log("==== Stats of Withdrawals ====");
    console.log("> Average Time: " + averageWithdrawalTime + "ms");
    console.log("> Average Gas cost: " + averageWithdrawalGas + " gas\n");
}

async function makeDeposit(mixerInstance, fromAccount, pubX, pubY) {
    // Deposit 1 Wei into mixer
    const txValue = 1;
    const token = 0; // 0 = ether
    const txObj = { from: fromAccount, value: txValue };

    // Start the timer
    var timeBegin = getTime();

    let result = await mixerInstance.Deposit(token, txValue, pubX, pubY, txObj);

    // End the timer
    var timeEnd = getTime();

    var timeSpent = timeEnd - timeBegin;
    var gasUsed = result.receipt.gasUsed;

    const depositEvent = result.logs.find(el => (el.event === 'MixerDeposit'));
    if (depositEvent) {
      console.log("> Handled MixerDeposit Event");
    }
    const readyEvent = result.logs.find(el => (el.event === 'MixerReady'));
    if (readyEvent) {
      console.log("> Handled MixerReady Event ");
    }

    console.log("==== TIME taken: " + timeSpent.toString() + "ms ====");
    console.log("==== GAS used: " + gasUsed.toString() + " gas ====\n");

    return {timeSpent: timeSpent, gasUsed: gasUsed, ringGuid: depositEvent.args.ring_id, ringMsg: (readyEvent)? readyEvent.args.message : null};
}

async function makeDummyDeposit(mixerInstance, fromAccount, pubX, pubY) {
    // Deposit 1 Wei into mixer
    const txValue = 1;
    const token = 0; // 0 = ether
    const txObj = { from: fromAccount, value: txValue };

    // Start the timer
    var timeBegin = getTime();

    let result = await mixerInstance.DummyDeposit(token, txValue, pubX, pubY, txObj);

    // End the timer
    var timeEnd = getTime();

    var timeSpent = timeEnd - timeBegin;
    var gasUsed = result.receipt.gasUsed;

    const depositEvent = result.logs.find(el => (el.event === 'MixerReceivedEther'));
    if (depositEvent) {
      console.log("> Handled MixerReceivedEther Event");
    }

    console.log("==== TIME taken: " + timeSpent.toString() + "ms ====");
    console.log("==== GAS used: " + gasUsed.toString() + " gas ====\n");

    return {timeSpent: timeSpent, gasUsed: gasUsed};
}

async function makeWithdrawal(mixerInstance, ringGuid, tau, ctlist) {

    // Start the timer
    var timeBegin = getTime();

    let result = await mixerInstance.Withdraw(ringGuid, tau.x, tau.y, ctlist);

    // End the timer
    var timeEnd = getTime();

    var timeSpent = timeEnd - timeBegin;
    var gasUsed = result.receipt.gasUsed;

    const withdrawEvent = result.logs.find(el => (el.event === 'MixerWithdraw'));
    if (withdrawEvent) { console.log("> Handled MixerWithdraw Event"); }

    console.log("==== TIME taken: " + timeSpent.toString() + "ms ====");
    console.log("==== GAS used: " + gasUsed.toString() + " gas ====\n");

    return {timeSpent: timeSpent, gasUsed: gasUsed};
}

async function depositAndWithdraw(mixerInstance, accounts){
    // Generate as many keys as the size of the ring, to fill it entirely
    const ringSize = 4;
    var keys = JSONBigInt.parse(orbitalGenerateKeys(ringSize));

    // Record the time and gas measurments in arrays in order to do some advanced stats
    var ringGuid;
    var ringMsg;

    for (var k = 0; k < ringSize; k++) {
        const pubkey = keys.pubkeys[k];

        let result = await makeDeposit(mixerInstance, accounts[0], pubkey.x, pubkey.y);

        // Add the measurments to the arrays
        ringGuid = result.ringGuid;
        ringMsg = result.ringMsg;
    }

    console.log("Ring ID = " + ringGuid.toString());
    console.log("Ring MESSAGE = " + ringMsg.toString());

    // Withdrawals
    // Generate inputs from ring keys
    const inputs = await generateAndVerifySignature(keys, ringMsg);

    // Then perform all the withdraws
    var timeArray = [];
    var gasCostArray = [];
    console.log("\nMaking withdrawals");
    for (var j = 0; j < inputs.signatures.length; j++) {
        const sig = inputs.signatures[j];
        const tau = sig.tau;
        const ctlist = sig.ctlist;

        let result = await makeWithdrawal(mixerInstance, ringGuid, tau, ctlist);

        timeArray.push(result.timeSpent);
        gasCostArray.push(result.gasUsed);
    }

    return {time: timeArray, gas: gasCostArray};
}

contract('Mixer', (accounts) => {
    var numberOfRings = 5;
    const ringSize = 4;

    it('Benchmark: Average Performances of an ether transfer', async () => {

        // Analysis variables
        let instance = await Mixer.deployed();
        var keys = JSONBigInt.parse(orbitalGenerateKeys(1));

        var results = [];
        for (var i = 0; i < numberOfRings; i++) {
            let result = await makeDummyDeposit(instance, accounts[0], keys.pubkeys[0].x, keys.pubkeys[0].y)
            results.push(result);
        }

        console.log("\n=============================================================")
        console.log("\n======= Starting withdrawal benchmark result analysis =======\n")
        console.log("=============================================================\n")

        var totalTime = 0;
        var totalGas = 0;
        for (var i = 0; i < results.length; i++) {
            totalTime += results[i].timeSpent;
            totalGas += results[i].gasUsed;
        }

        var averageTime = parseInt(totalTime/results.length);
        var averageGas = parseInt(totalGas/results.length);

        console.log("==== Stats of an ether transfer to contract only' ====");
        console.log("> Average Time: " + averageTime + "ms");
        console.log("> Average Gas cost: " + averageGas + " gas\n");

    });

    it('Benchmark: Average Performances of a Deposit to the Mixer', async () => {

        // Analysis variables
        var ringResult = [];

        // Using the Truffle contract abstraction
        let instance = await Mixer.deployed();

        // The number of rings to fill during this benchmark
        for (var i = 0; i < numberOfRings; i++) {
            console.log("\n==== Starting deposit benchmark for ring number " + (i + 1).toString() + " ====\n");

            // Generate as many keys as the size of the ring, to fill it entirely
            var keys = JSONBigInt.parse(orbitalGenerateKeys(ringSize));

            // Record the time and gas measurments in arrays in order to do some advanced stats
            var timeArray = [];
            var gasCostArray = [];

            for (var k = 0; k < ringSize; k++) {
                const pubkey = keys.pubkeys[k];

                let result = await makeDeposit(instance, accounts[0], pubkey.x, pubkey.y);

                // Add the measurments to the arrays
                timeArray.push(result.timeSpent);
                gasCostArray.push(result.gasUsed);
            }

            ringResult.push({time: timeArray, gas: gasCostArray});
        }

        parseDepositBenchmarkResults(ringResult);

    });

    it('Benchmark: Average Performances of a Withdrawal to the Mixer', async () => {

        // Analysis variables
        var ringResult = [];

        // Using the Truffle contract abstraction
        let instance = await Mixer.deployed();

        for (var i = 0; i < numberOfRings; i++) {
            console.log("\n==== Starting withdraw benchmark for ring number " + (i + 1).toString() + " ====\n");
            let result = await depositAndWithdraw(instance, accounts);

            ringResult.push(result);
        }

        parseWithdrawBenchmarkResults(ringResult);

    });
});
