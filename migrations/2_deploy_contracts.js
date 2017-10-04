var Ring = artifacts.require("./Ring.sol");

module.exports = function(deployer) {
  deployer.deploy(Ring, 4, 1);
};
