// Copyright (c) 2016-2018 Clearmatics Technologies Ltd

// SPDX-License-Identifier: LGPL-3.0+

const fs = require('fs');
const path = require('path');
const shellescape = require('shell-escape');
const { execSync } = require('child_process');
const tmp = require("tmp");
const JSONBigInt = require('json-bigint-string');

// Truffle contract abstractions
const Mixer = artifacts.require("./Mixer.sol");
const BenchmarkMixer = artifacts.require("./BenchmarkMixer.sol");

// Global constants used in the benchmark (The ring size has to match the RING_SIZE var in LinkableRing.sol)
const ringSize = 10;
const numberOfRings = 3;

// Global variable that contains the result of each tests
var resultOfTheBenchmark = {};

/** Implements functionality similar to the 'which' shell command **/
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

/** Filesystem path of the 'orbital' command line tool **/
const defaultOrbitalBinPath = "/home/user/go/src/github.com/clearmatics/orbital/orbital";
function findOrbital () {
    var foundWithWhich = which("orbital", defaultOrbitalBinPath);
    if( ! foundWithWhich || ! fs.existsSync(foundWithWhich) ) {
        return null;
    }
    return foundWithWhich;
}

/** Execute `orbital` command, with array of arguments **/
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
    const inputs_txt = orbital(['inputs', '-k', keys_file.name, '-n', ringSize, '-m', ringMsg.substr(2)]);
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

/** computeMatrixMean takes a matrix as argument which is intepreted as a set of arrays
 * The function returns an array which values are the mean of the the set of values of
 * same indexin the set of arrays composing the matrix.
 **/
function computeMatrixMean(matrix) {
  var nbLines = matrix.length; // Number of arrays composing the matrix
  if (nbLines <= 0) {
    console.error("Invalid dimension for the matrix");
    return null;
  }

  var nbColumns = matrix[0].length; // Number of elements of the first array. We assume that all arrays have the same length

  var meanArray = [];
  for (var c = 0; c < nbColumns; c++) {
    temp = [];
    for (var l = 0; l < nbLines; l++) {
      temp.push(matrix[l][c]);
    }
    var meanIndex = getAverage(temp);
    meanArray.push(meanIndex);
  }

  return meanArray;
}

function getBenchmarkAnalysis(timeMatrix, gasMatrix) {
  var averageTimeArray = computeMatrixMean(timeMatrix);
  var averageGasArray = computeMatrixMean(gasMatrix);

  return {timeArray: averageTimeArray, gasArray: averageGasArray};
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

    return {
      timeSpent: timeSpent,
      gasUsed: gasUsed,
      ringGuid: depositEvent.args.ring_id,
      ringMsg: (readyEvent)? readyEvent.args.message : null
    };
}

async function makeBenchmarkDeposit(benchmarkMixerInstance, fromAccount, pubX, pubY) {
    const txValue = 1;
    const token = 0;
    const txObj = { from: fromAccount, value: txValue };

    // Start the timer
    var timeBegin = getTime();

    let result = await benchmarkMixerInstance.BenchmarkDeposit(token, txValue, pubX, pubY, txObj);

    // End the timer
    var timeEnd = getTime();

    var timeSpent = timeEnd - timeBegin;
    var gasUsed = result.receipt.gasUsed;

    const depositEvent = result.logs.find(el => (el.event === 'MixerBenchmarkEvent'));
    if (depositEvent) {
      console.log("> Handled MixerBenchmarkEvent Event");
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

async function makeBenchmarkWithdraw(benchmarkMixerInstance) {
    // Start the timer
    var timeBegin = getTime();

    let result = await benchmarkMixerInstance.BenchmarkWithdraw(123456, 123456, 123456, [123456, 123456]);

    // End the timer
    var timeEnd = getTime();

    var timeSpent = timeEnd - timeBegin;
    var gasUsed = result.receipt.gasUsed;

    const depositEvent = result.logs.find(el => (el.event === 'MixerBenchmarkEvent'));
    if (depositEvent) {
      console.log("> Handled MixerBenchmarkEvent Event");
    }

    console.log("==== TIME taken: " + timeSpent.toString() + "ms ====");
    console.log("==== GAS used: " + gasUsed.toString() + " gas ====\n");

    return {timeSpent: timeSpent, gasUsed: gasUsed};
}

async function depositAndWithdraw(mixerInstance, accounts){
    // Generate as many keys as the size of the ring, to fill it entirely
    var keys = JSONBigInt.parse(orbitalGenerateKeys(ringSize));

    var ringGuid;
    var ringMsg;

    var resultDeposit;
    for (var k = 0; k < ringSize; k++) {
        const pubkey = keys.pubkeys[k];

        //let result = await makeDeposit(mixerInstance, accounts[0], pubkey.x, pubkey.y);
        resultDeposit = await makeDeposit(mixerInstance, accounts[0], pubkey.x, pubkey.y);

        //ringGuid = result.ringGuid;
        //ringMsg = result.ringMsg;
        ringGuid = resultDeposit.ringGuid;
        ringMsg = resultDeposit.ringMsg;
    }
    // ringGuid = resultDeposit.ringGuid;
    // ringMsg = resultDeposit.ringMsg;

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

        let resultWithdraw = await makeWithdrawal(mixerInstance, ringGuid, tau, ctlist);

        timeArray.push(resultWithdraw.timeSpent);
        gasCostArray.push(resultWithdraw.gasUsed);
    }

    return {time: timeArray, gas: gasCostArray};
}

contract('Mixer', (accounts) => {
    it('Benchmark: Calculating the cost to make a Deposit to the BenchmarkMixer', async () => {
        let benchmarkInstance = await BenchmarkMixer.deployed();
        var keys = JSONBigInt.parse(orbitalGenerateKeys(1));

        var results = [];
        for (var i = 0; i < numberOfRings; i++) {
            let result = await makeBenchmarkDeposit(benchmarkInstance, accounts[0], keys.pubkeys[0].x, keys.pubkeys[0].y)
            results.push(result);
        }

        var totalTime = 0;
        var totalGas = 0;
        for (var i = 0; i < results.length; i++) {
            totalTime += results[i].timeSpent;
            totalGas += results[i].gasUsed;
        }

        var averageTime = parseInt(totalTime/results.length);
        var averageGas = parseInt(totalGas/results.length);

        console.log("==== Stats of a deposit to the benchmark mixer contract ====");
        console.log("> Average Time: " + averageTime + "ms");
        console.log("> Average Gas cost: " + averageGas + " gas\n");

    });

    it('Benchmark: Average Performances of a Deposit to the Mixer', async () => {
        var depositResult = [];
        var timeMatrix = [];
        var gasMatrix = [];

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

            timeMatrix.push(timeArray);
            gasMatrix.push(gasCostArray);
        }

        var depositAnalysis = getBenchmarkAnalysis(timeMatrix, gasMatrix);
        // Adding a field to the result object containing the result of the deposit test
        resultOfTheBenchmark["deposit"] = JSON.stringify(depositAnalysis);
    });

    it('Benchmark: Calculating the cost to Withdraw from the BenchmarkMixer', async () => {
        let benchmarkInstance = await BenchmarkMixer.deployed();
        var keys = JSONBigInt.parse(orbitalGenerateKeys(1));

        var results = [];
        for (var i = 0; i < numberOfRings; i++) {
            // Call makeBenchmarkWithdraw with mock parameters (they are not used in the logic of the function)
            let result = await makeBenchmarkWithdraw(benchmarkInstance)
            results.push(result);
        }

        var totalTime = 0;
        var totalGas = 0;
        for (var i = 0; i < results.length; i++) {
            totalTime += results[i].timeSpent;
            totalGas += results[i].gasUsed;
        }

        var averageTime = parseInt(totalTime/results.length);
        var averageGas = parseInt(totalGas/results.length);

        console.log("==== Stats of a deposit to the benchmark mixer contract ====");
        console.log("> Average Time: " + averageTime + "ms");
        console.log("> Average Gas cost: " + averageGas + " gas\n");

    });

    it('Benchmark: Average Performances of a Withdrawal to the Mixer', async () => {
        var timeMatrix = [];
        var gasMatrix = [];

        let instance = await Mixer.deployed();

        for (var i = 0; i < numberOfRings; i++) {
            console.log("\n==== Starting withdraw benchmark for ring number " + (i + 1).toString() + " ====\n");
            let result = await depositAndWithdraw(instance, accounts);

            timeMatrix.push(result.time);
            gasMatrix.push(result.gas);
        }

        var withdrawAnalysis = getBenchmarkAnalysis(timeMatrix, gasMatrix);

        // Adding a field to the result object containing the result of the withdrawal test
        resultOfTheBenchmark["withdraw"] = JSON.stringify(withdrawAnalysis);
    });

    it('Saving the result of the Benchmark in ./benchmark.txt', async () => {
      let contentToSave = "var result = " + JSON.stringify(resultOfTheBenchmark);
      fs.writeFile('benchmark.txt', contentToSave, (err) => {
        // throws an error, you could also catch it here
        if (err) throw err;

        // success case, the file was saved
        console.log('Benchmark statistics successfully saved !');
      });
    });
});
