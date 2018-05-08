var Shorting = artifacts.require("./Shorting.sol");
var TokenOracle = artifacts.require("./TokenOracle.sol");
var KyberNetwork = artifacts.require("./lib/kyber/KyberNetwork.sol");
var TokenA = artifacts.require("./lib/tokens/TokenA.sol");
var TokenB = artifacts.require("./lib/tokens/TokenB.sol");

module.exports = function(deployer, network, accounts) {
	// accounts[0] is the owner/minter of every contract by default
	const user1 = accounts[1];
	const user2 = accounts[2];

	deployer
		.deploy([[TokenA], [TokenB]])
		.then(() => {
			// TokenA is base token
			return deployer.deploy(TokenOracle, TokenA.address);
		})
		.then(() => {
			return deployer.deploy(KyberNetwork, TokenOracle.address);
		})
		.then(() => {
			return deployer.deploy(
				Shorting,
				KyberNetwork.address,
				TokenOracle.address
			);
		});
};
