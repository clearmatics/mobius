var Mobius = artifacts.require("./Mobius.sol");

module.exports = function(deployer) {
  deployer.deploy(Mobius, 4, 1);
};
