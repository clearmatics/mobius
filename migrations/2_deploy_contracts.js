const Ring_tests = artifacts.require("./LinkableRing_tests.sol");

const Mixer = artifacts.require("./Mixer.sol");
const Mixer_tests = artifacts.require("./Mixer_tests.sol");

const bn256g1_tests = artifacts.require("./bn256g1_tests.sol");

module.exports = (deployer) => {
  deployer.deploy(bn256g1_tests, 4, 100000000000000000, 0);

  deployer.deploy(Ring_tests, 4, 100000000000000000, 0);

  deployer.deploy(Mixer, 4, 100000000000000000, 0);
  deployer.deploy(Mixer_tests, 4, 100000000000000000, 0);

};
