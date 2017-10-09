const Ring = artifacts.require("./Ring.sol");

const inputDataWithdraw = [
    [
        '9534944482219513014797815640985781724703938193618711499459191732703920451273',
        '83977657382022678730872600086425077306476469040270828852112498544704890379910',
        [
            '99108845111710174881671543525936933840803511220626928702989677776636338216353',
            '77560226011962847333095250081594488770278757404064147166253092102181587910825',
            '113404631286866677630080035599481516785308307105767279667904411148792996043050',
            '7039895496367124457474908488289890935845641056992941297528764048259944617938',
            '9222005450310207249800670764808467616758835880185660924607011394596460385056',
            '36635213900338797629210832067497453623596183474122022797409315026150489916557',
            '71606876918523381738827527103973913986172253864213184153990415248685877317422',
            '55473242028923081898769646947797497173188889033801679543089292664960052253406'
        ]
    ],
    [
        '51256599143484429555534076868518201445857449725470257833258523775667559442946',
        '100817223760279953534244621890939804676378204769624382839781927565811955386443',
        [
            '111001900993416103310501543016946414981983475049745872181448128594747431520707',
            '7053369587723946604066145605626304692116160319444017577224627982985645724465',
            '76615638135299659587069661815298865183337080333759340717610668820819948582366',
            '109169989894294272063476968912911456937622038404123172204323980272522152031947',
            '35844088051004101681851792522287003542191553177052848307433411556445696848560',
            '20251883804313439174383393785935806856003435752379035254549800436531776832260',
            '519427451890219754864399264491572083746359139366101566899246691437982697545',
            '5188793200244291343603141385550504364119318433446439743192386143921712195187'
        ]
    ],
    [
        '12677662591794380635739096310315458148429048378066648619909405886852202730789',
        '79698593343749438543093289930757610680077485213734485042091125503259889195059',
        [
            '11212785790261904816848973907840644577315731773727174653834312607329799899414',
            '67646611100265403872129295040537066871125541778005513599971061175286393987812',
            '98523742102772860062542775202434999750625078715424264475764870757765212768848',
            '72554665823498346630456183172045526308521976169465583310565596779616467229051',
            '78874735185774024327446786367582781382902879714863666163658616503485256836611',
            '38652776398533862117602467409517047500032566587604990958576674787254961131451',
            '114864757266512427562641694429635497452305490506669901702438262282766346433989',
            '43714314979862200787607091305945193474923902888500595610328181543877197322742'
        ]
    ],
    [
        '28966946623337064353358713639988056053205525846950942265398043562576534216417',
        '17390516198864590808630446412044612730207719917456489026430849171973064775524',
        [
            '99955057148674655509873991386839863995132528630791734004392270299318859656605',
            '16296052101061679325125859026678478858472480514216758068348445005698255046330',
            '5526403459821190498237512067442579952636095155402078813606901086367385292187',
            '60466346148357997712253522217320746983029417176639681713282527636650008979079',
            '113489005039802492855370519538188242425175421664598917436295451417598298774907',
            '15732147467497289250408642953779317709452347127404605557099293442708797105538',
            '61342275596318765157795230457180943847688521059134341520898127321687292070341',
            '36344331311635033390395680995710425635622018511363918774421827104709316412750'
        ]
    ]
];

const inputDataDeposit = [
    [
        '93382074010389671847765603537707381883068931496691943797480161536572962548490',
        '10987150931043373241587165672792066486099792484850875143978264661388769250490'
    ],
    [
        '9057112552080892979657731541118168018927180086722027824589339200716559871772',
        '15904845856551647973906218013889484651898890002396375700253101936172779175162'
    ],
    [
        '74685815710198744554993941186345408158819435702423511446221591253414967957132',
        '27817648998723895158469863314657094232317028668308011975651110743919844333531'
    ],
    [
        '93254489167282381547961099120178526236388198471665013588274431726510445669351',
        '94384171320940413965004957544913330057681881724343933230094119918469549839386'
    ]
];

contract('Ring', (accounts) => {
    it('Starting the contract', (done) => {
        Ring.deployed().then((instance) => {
            const owner = accounts[0];
            const txObj = { from: owner };
            instance.start(txObj).then(result => {
                const contractBalance = web3.eth.getBalance(instance.address).toString();
                const title = '================= CONTRACT STATUS ================= ';
                console.log(title,'\nBALANCE:',contractBalance);
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
            const txPromises = inputDataDeposit.map(data => {
                const pubPosX = data[0];
                const pubPosY = data[1];
                return instance.deposit(pubPosX, pubPosY, txObj)
                    .then(result => {
                        const txObj = web3.eth.getTransaction(result.tx);
                        const receiptStr = JSON.stringify(result,null,'\t');
                        const txStr = JSON.stringify(txObj,null,'\t');
                        const title = '================= DEPOSIT ================= ';
                        console.log(title,'\nRECEIPT:\n',receiptStr,'\nTRANSACTION:\n',txStr)
                        return result;
                    });
            });
            Promise.all(txPromises).then((result) => {

                //console.log(result)
                result.forEach(res => {
                    const expected = res.logs.some(el => (el.event === 'NewParticipant'));
                    assert.ok(expected, 'NewParticipant event was not emitted');
                });

                const contractBalance = web3.eth.getBalance(instance.address).toString();
                const title = '================= CONTRACT STATUS ================= ';
                console.log(title,'\nBALANCE:',contractBalance);
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
                const signature = data[2]; // ct list?!
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
                //.then(result => {
                //    console.log('LOG: ',result.logs);
                //    return result;
                //});
            });

            Promise.all(txPromises).then((result) => {

                const contractBalance = web3.eth.getBalance(instance.address).toString();
                const title = '================= CONTRACT STATUS ================= ';
                console.log(title,'\nBALANCE:',contractBalance);
                assert.deepEqual(contractBalance, web3.toWei(0, 'ether'))
                done();
            });
        });
    }).timeout(0);
});
