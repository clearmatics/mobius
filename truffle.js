module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8550,
      network_id: "*" // Match any network id
    },
    ci: {
      host: "harshjv-testrpc",
      port: 8545,
      network_id: "*" // Match any network id
    }
  },
  mocha: {
    useColors: true
  },
  solc: {
    optimizer: {
      enabled: true,
        runs: 200
    }
  }
};
