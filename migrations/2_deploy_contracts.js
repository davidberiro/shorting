var Shorting = artifacts.require("./Shorting.sol");
var TokenOracle = artifacts.require("./TokenOracle.sol");
var KyberNetwork = artifacts.require("./lib/kyber/KyberNetwork.sol");
var TokenA = artifacts.require("./lib/tokens/TokenA.sol");
var TokenB = artifacts.require("./lib/tokens/TokenB.sol");


module.exports = function(deployer, network, accounts) {
  
  deployer.deploy([
    [TokenA],
    [TokenB],
    [Shorting],
  ]).then(() => {
    deployer.deploy(TokenOracle, TokenA.address)
  }).then(() => {
    deployer.deploy(KyberNetwork, TokenOracle.address)
  }).then(() => {
    //set token rates (TODO) for testing purposes
  })
};
