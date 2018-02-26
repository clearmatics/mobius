const Ring_tests = artifacts.require("./LinkableRing_tests.sol");
const Mixer = artifacts.require("./Mixer.sol");
const bn256g1_tests = artifacts.require("./bn256g1_tests.sol");
const BenchmarkMixer = artifacts.require("./BenchmarkMixer.sol");

module.exports = (deployer) => {
  deployer.deploy(bn256g1_tests);

  deployer.deploy(Ring_tests);

  deployer.deploy(Mixer);

  deployer.deploy(BenchmarkMixer);
};
