var Mobius = artifacts.require("./Mobius.sol");

var fixtures = [ 
  [
    "9534944482219513014797815640985781724703938193618711499459191732703920451273",
    "83977657382022678730872600086425077306476469040270828852112498544704890379910"
  ],
  [
    "51256599143484429555534076868518201445857449725470257833258523775667559442946",
    "100817223760279953534244621890939804676378204769624382839781927565811955386443"
  ],
  [
    "12677662591794380635739096310315458148429048378066648619909405886852202730789",
    "79698593343749438543093289930757610680077485213734485042091125503259889195059"
  ],
  [
    "28966946623337064353358713639988056053205525846950942265398043562576534216417",
    "17390516198864590808630446412044612730207719917456489026430849171973064775524"
  ]
]

contract('Mobius', function(accounts) {
  before(function() {
    return Mobius.deployed()
  });
        
  it("should emit a RingMessage event when started", function() {
    return Mobius.deployed().then(function(instance) {
      return instance.start()
    }).then(function(result){
      var expected = result.logs.some(function(el) {
        return el.event === 'RingMessage';
      });
      return expected;
    }).catch(function(err) {
      console.log(err);
    }).then(function(expected) {
      return assert.ok(expected, "RingMessage event was not emitted")
    });
  });

});
    //}).then(function(instance){
     // return instance.deposit(inputs[0][0], inputs[0][1], {from: accounts[0], value: web3.toWei(1, "ether")})
   // }).then(function(result){
    //  return meta.deposit(inputs[1][0], inputs[1][1], {from: accounts[0], value: web3.toWei(1, "ether")})
   // }).then(function(result){
    //  console.log(meta.address)
     // console.log(web3.eth.getBalance(meta.address).toString())
      //console.log(web3.eth.getBalance(accounts[0]).toString())
    //});
