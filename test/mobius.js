const Ring = artifacts.require("./Ring.sol");
const ringSignature = require("./ringSignature");

const inputDataDeposit = ringSignature.ring.map(d => [d.x, d.y]);
const inputDataWithdraw = ringSignature.signatures.map(d => [d.tau.x, d.tau.y, d.ctlist]);

console.log('inputDataDeposit:',JSON.stringify(inputDataDeposit,null,'\t'));
console.log('inputDataWithdraw:',JSON.stringify(inputDataWithdraw,null,'\t'));

contract('Ring', (accounts) => {
    it('Starting the contract', (done) => {
        Ring.deployed().then((instance) => {
            const owner = accounts[0];
            const txObj = { from: owner };
            instance.start(txObj).then(result => {
                const contractBalance = web3.eth.getBalance(instance.address).toString();
                const title = '================= CONTRACT STATUS ================= ';
                console.log(title,'\nADDRESS:',instance.address,'\nBALANCE:',contractBalance);
                const expected = result.logs.some(el => (el.event === 'RingMessage'));
                assert.ok(expected, "RingMessage event was not emitted")
                done();
            });
        });
    });


    it('Deposit in ring and create particpants', (done) => {
        Ring.deployed().then((instance) => {
            const depositValue = 1;
            const owner = accounts[0];
            const txObj = { from: owner, value: web3.toWei(depositValue, 'ether') };
            const txPromises = inputDataDeposit.reduce((prev, data) => {
                const pubPosX = data[0];
                const pubPosY = data[1];
                const executeDeposit = () => {
                    return instance.deposit(pubPosX, pubPosY, txObj)
                        .then(result => {
                            const txObj = web3.eth.getTransaction(result.tx);
                            const receiptStr = JSON.stringify(result,null,'\t');
                            const txStr = JSON.stringify(txObj,null,'\t');
                            const title = '================= DEPOSIT ================= ';
                            console.log(title,'\nRECEIPT:\n',receiptStr,'\nTRANSACTION:\n',txStr)
                            return result;
                        });
                };
                return (prev ? prev.then(executeDeposit) : executeDeposit());
            }, undefined);
            txPromises.then((result) => {
                const expected = result.logs.some(el => (el.event === 'NewParticipant'));
                assert.ok(expected, 'NewParticipant event was not emitted');

                const contractBalance = web3.eth.getBalance(instance.address).toString();
                const title = '================= CONTRACT STATUS ================= ';
                console.log(title,'\nADDRESS:',instance.address,'\nBALANCE:',contractBalance);
                assert.deepEqual(contractBalance, web3.toWei(depositValue*inputDataDeposit.length, 'ether'));
                done();
            });
        });
    });

    it('Withdraw from the ring', (done) => {
        Ring.deployed().then((instance) => {
            const owner = accounts[0];
            const txObj = { from: owner, gas: 16000000 };
            const txPromises = inputDataWithdraw.map((data,i) => {
                const pubPosX = data[0];
                const pubPosY = data[1];
                const signature = data[2]; // ctlist
                return instance.withdraw(pubPosX, pubPosY, signature, txObj)
                    .then(result => {
                        const txObj = web3.eth.getTransaction(result.tx);
                        const receiptStr = JSON.stringify(result,null,'\t');
                        const txStr = JSON.stringify(txObj,null,'\t');
                        const title = '================= WITHDRAW ================= ';
                        console.log(title,'\nRECEIPT:\n',receiptStr,'\nTRANSACTION:\n',txStr)
                        return result;
                    })
                    .then(res => {
                        const expected = res.logs.some(el => (el.event === 'WithdrawEvent'));
                        assert.ok(expected, 'Withdraw event was not emitted');
                    });
            });

            Promise.all(txPromises).then((result) => {

                const contractBalance = web3.eth.getBalance(instance.address).toString();
                const title = '================= CONTRACT STATUS ================= ';
                console.log(title,'\nADDRESS:',instance.address,'\nBALANCE:',contractBalance);
                assert.deepEqual(contractBalance, web3.toWei(0, 'ether'))
                done();
            });
        });
    }).timeout(0);
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
 */
