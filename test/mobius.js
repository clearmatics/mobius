const Ring = artifacts.require("./Ring.sol");

// hexdacimal to decimal string
const h2d = s => {
    const add = (xStr, yStr) => {
        let c = 0, r = [];
        let x = xStr.split('').map(Number);
        let y = yStr.split('').map(Number);
        while(x.length || y.length) {
            let s = (x.pop() || 0) + (y.pop() || 0) + c;
            r.unshift(s < 10 ? s : s - 10);
            c = s < 10 ? 0 : 1;
        }
        if(c) r.unshift(c);
        return r.join('');
    }

    let dec = '0';
    s.split('').forEach(chr => {
        let n = parseInt(chr, 16);
        for(let t = 8; t; t >>= 1) {
            dec = add(dec, dec);
            if(n & t) dec = add(dec, '1');
        }
    });
    return dec;
};

const pub = {
    "pubkeys": [
        {
            "x": "ecd49335a81f5c3f064c1dd1b957d9eb8cf0c460af94bfdc5d729b677a00648b",
            "y": "5be01b38340cb3f0c6222691c7565dc01a10221a9280cb12f4fa2913e34f1213"
        },
        {
            "x": "73f7b7426040f8d0d8155b62ce1a01a711d07b0b463103f9824e9c6d0c3d6dac",
            "y": "4bf85ccf65cee73656255259ff32c358490a43a9eb12296326884e31dd33dba9"
        },
        {
            "x": "d16d068bb8195cc9a90320469c5b3c2e8c5b2c6e2361c68c97c2297788a95339",
            "y": "c6058cec7a04e257e5cf77a6db5db74f820aef4f4d73203cf33035ca35f9fa81"
        },
        {
            "x": "243862f64b87ccdf46f66ee30ceffd3b3949f0bc73f413870d29fe82e8d70bd4",
            "y": "25f4fc6bd9d9860a87d6feca5bf2fdfac2d871cd328f24d3ef907618dba4b9fa"
        }
    ]
};

const inputDataDeposit = pub.pubkeys.map(p => [h2d(p.x),h2d(p.y)]);
const inputDataWithdraw = [
    [
        '106366439398603416822247119626287840524355113743692005225105545445059103990809',
        '67025358500250496745755247062298485383323940337408928096381589383037991479556',
        [
            '22901674468094863790481557638758200277253773755756545145885863494090923916490',
            '113867609781387097841303343489264120285544391237237808811941796948665461477727',
            '10377872787323337032533342229535953138011742058174771048930099238398074807717',
            '70271019341829664021604165841268759191426500582784335713830861175853427133277',
            '9473614243894181813333245805101422276134981246777745013465333856377603793584',
            '83433423973088076407224961028517300259236671767256366060282201497883517077192',
            '8141890751671832070716413493094953662643330625471114172931223764125024503317',
            '28952408608755014616966651707366077102677560443741279949271396798665115594575'
        ]
    ],
    [
        '88975504728434974553291498940586064575106864605203430999807949961102786040399',
        '82533270363644289553677780427377972398692841817615709365379639236869917397038',
        [
            '70261712463773447751634206605639063932333635002794844272004090571653339934686',
            '48573419035034166779749772037176373159175073625928351864492675259284905530598',
            '39515630543217862190853526702602603427068633661184819259939835755339809064522',
            '23892243776941700675276861531961202981911592923257591407664622916208173141074',
            '30888165740156910421293686051669994279012958836190882919541890246937735147082',
            '85917976669841410765505367913757024509228247801234859729080444050969431632252',
            '68549429533210985856398361619979784783624521989926223529860199444413432629502',
            '53429376268908337233314881716998411507506581471400156844303458063630073315279'
        ]
    ],
    [
        '69671387938994181960964759231244490936475418963932365065846439667148728608546',
        '43627567885216418172336149963886655004826396404365031783085914945038481106905',
        [
            '104704992357339222470749982825751789700572726518800434908009356823855303903151',
            '106758597705072089939737634462543644651959582299182344457826608294030678395045',
            '84042391524277464092855581766017816807812895365569254416870355815769068378511',
            '60241330672913371969692136711157595100229936320864275676354532916955165827221',
            '27134451538582959899573049089921801084055127760352198084638263639716097835946',
            '65763528886653499955234684759735655236441392169868996752844678719743073004964',
            '45941360085030647047806057702183538931706871481745773750738768375163545083761',
            '62025372756038221118742473914450531120630675674742509856102633399762218767732'
        ]
    ],
    [
        '88473990958147884621701955194133739096609589891823229906078527021254138233166',
        '108989644199423786137325059897026797817858983245080573753255417163409575309391',
        [
            '16843276821153893080012885145937315417553467731741417855850729705603734862922',
            '44059712278950746093247789322542107389426306312146346493382982307487142183478',
            '41468224369236923683029111482726588359591789493158167128395654575483925407445',
            '48797437717500808680513427841046768516733884667413557451760369906549085111503',
            '49830418463118148064888575550784748920509061168516654283432759482336522886072',
            '86037764701667538630234887164405727884034483300717349155529763673117156535204',
            '87589294674638344630885958570380309588849167944859493775229828922762493308464',
            '21875451732193259884854853978520014881746283262267456179112307742613607632126'
        ]
    ]
]

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
                console.log(title,'\nADDRESS:',instance.address,'\nBALANCE:',contractBalance);
                assert.deepEqual(contractBalance, web3.toWei(0, 'ether'))
                done();
            });
        });
    }).timeout(0);
});
