var Ring = artifacts.require("./Ring.sol");

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

var meta;

contract('Ring', function(accounts) {


  //context('Starting the contract', function() {

    it("should emit a RingMessage event when started", function() {
      return Ring.deployed().then(function(instance) {
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

  //});

  context('Making payments to the ring', function() {

    it("should accept payments with valid data", function() {
      return Ring.deployed().then(function(instance) {
        return instance;
      }).then(function(instance){
        meta = instance
        return instance.deposit('88975504728434974553291498940586064575106864605203430999807949961102786040399', '82533270363644289553677780427377972398692841817615709365379639236869917397038', {from: accounts[0], value: web3.toWei(1, "ether")})

      }).then(function(result){
        assert.deepEqual(web3.eth.getBalance(meta.address).toString(), "1000000000000000000")
      });

    });

  });

});
