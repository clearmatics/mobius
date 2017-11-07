const Ring = artifacts.require("./Ring.sol");
const ringSignature = require("./ringSignature");

const inputDataDeposit = ringSignature.ring.map(d => [d.x, d.y]);
const inputDataWithdraw = ringSignature.signatures.map(d => [d.tau.x, d.tau.y, d.ctlist]);

contract('Ring', (accounts) => {
    it('Deploy the contract', (done) => {
        Ring.deployed().then((instance) => {     
            var availableForDeposit = instance.AvailableForDeposit({fromBlock: "latest"});
            assert.ok(availableForDeposit, 'Available for deposit event was not emitted');
           
            done();            
        });
    });

    it('Starting the contract', (done) => {
        Ring.deployed().then((instance) => {           
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

    it('Deposit in ring and create particpants', (done) => {
        Ring.deployed().then((instance) => {
            const depositValue = 1;
            const owner = accounts[0];
            const txValue = web3.toWei(depositValue, 'ether');
            const txObj = { from: owner, value: txValue };
            
            const txPromises = inputDataDeposit.reduce((prev, data) => {
                const pubPosX = data[0];
                const pubPosY = data[1];
                
                const executeDeposit = () => {
                    return instance.deposit(pubPosX, pubPosY, txValue, txObj)
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
                const expected = result.logs.some(el => (el.event === 'NewParticipant'));
                assert.ok(expected, 'NewParticipant event was not emitted');

                const contractBalance = web3.eth.getBalance(instance.address).toString();
                assert.deepEqual(contractBalance, web3.toWei(depositValue*inputDataDeposit.length, 'ether'));
                done();
            });
        });
    });

    it('Withdraw from the ring', (done) => {
        Ring.deployed().then((instance) => {
            const owner = accounts[0];
            const txObj = { from: owner, gas: 16000000 };
            
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

});

/*
 * test ideas
 *
* submitting a transaction once the ring is full
* submitting a deposit with a bad signature
* submitting a withdrawal with bad data
* submitting a transaction with a bad transaction value (e.g. submitting a payment of 1 when the ring size is 5)
* changing input types to the wrong values (e.g. make an int a string)
* submitting a withdrawal twice
* submitting a deposit twice to the same withdraw address
 */
