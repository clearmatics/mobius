module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
      from: "0x43c719ee71a6212abd2d6d796e589089fdc1e88d",
      gas: 3112883
    },
    ci: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    coverage: {
      host: "localhost",
      port: 8555,
      network_id: "*", // Match any network id
      gas: 0xFFFFFFF,
      gasprice: 0x1
    }
  },
  mocha: {
    useColors: true,
    enableTimeouts: false
  },
  solc: {
    optimizer: {
      enabled: true,
        runs: 200
    }
  }
};
