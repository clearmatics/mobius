const Ring_tests = artifacts.require("./Ring_tests.sol");
const Mixer = artifacts.require("./Mixer.sol");
const Mixer_tests = artifacts.require("./Mixer_tests.sol");
const bn256g1_tests = artifacts.require("./bn256g1_tests.sol");

const ringSignature = require("./ringSignature.bn256");

const inputDataDeposit = ringSignature.ring.map(d => [d.x, d.y]);
const inputDataWithdraw = ringSignature.signatures.map(d => [d.tau.x, d.tau.y, d.ctlist]);

const testContracts = {
    Ring_tests: Ring_tests,
    Mixer_tests: Mixer_tests,
    bn256g1_tests: bn256g1_tests
};

const allSimpleTests = {
    bn256g1_tests:  [
        "testOnCurve", "testHashToPoint", "testNegate", "testIdentity", "testEquality",
        "testOrder", "testModExp"
    ],
    Ring_tests: [
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
