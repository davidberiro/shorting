require("babel-polyfill");
const util = require("ethereumjs-util");
const ABI = require("ethereumjs-abi");

var Shorting = artifacts.require("./Shorting.sol");
var TokenA = artifacts.require("./lib/tokens/TokenA.sol");
var TokenB = artifacts.require("./lib/tokens/TokenB.sol");
var TokenOracle = artifacts.require("./TokenOracle.sol");
var KyberNetwork = artifacts.require("./lib/kyber/KyberNetwork.sol");

contract("Shorting", async accounts => {
	const owner = accounts[0];
	const user1 = accounts[1];
	const user2 = accounts[2];

	const logEvents = [];
	const pastEvents = [];

	let shorting;
	let tokenOracle;
	let kyberNetwork;
	let tokenA;
	let tokenB;
	let orderHash;

	it("deploys Shorting contract", async () => {
		shorting = await Shorting.deployed();
		// const eventsWatch = shorting.allEvents();
		// eventsWatch.watch((err, res) => {
		// 	if (err) return;
		// 	pastEvents.push(res);
		// 	// debug(">>", res.event, res.args);
		// });
		// logEvents.push(eventsWatch);
	});

	it("deploys tokenA and transfers 1000 tokenA to user1", async () => {
		tokenA = await TokenA.deployed();
		await tokenA.create(user1, 1000);
		assert.equal(await tokenA.balanceOf(user1), 1000);
	});

	it("deploys tokenB and transfers 1000 tokenB to user2", async () => {
		tokenB = await TokenB.deployed();
		await tokenB.create(user2, 1000);
		assert.equal(await tokenB.balanceOf(user2), 1000);
	});

	it("deploys TokenOracle and sets 1-1 rate between token A and B", async () => {
		tokenOracle = await TokenOracle.deployed();
		// tokenB => 1 * 10^18 means 1 * 10^18 tokenA == 1 * 10^18 tokenB
		let transaction = await tokenOracle.setRate(
			tokenB.address,
			Math.pow(10, 18)
		);
		assert.ok(
			transaction.logs.find(log => {
				return log.event === "RateSet";
			})
		);
	});

	it("deploys KyberNetwork and deposits 1000 token A and B into it", async () => {
		kyberNetwork = await KyberNetwork.deployed();
		await tokenA.create(kyberNetwork.address, 1000);
		await tokenB.create(kyberNetwork.address, 1000);
		assert.equal(await tokenA.balanceOf(kyberNetwork.address), 1000);
		// assert.equal(await tokenB.balanceOf(kyberNetwork.address), 1000);
	});

	it("approves the shorting contract to withdraw 500 tokenA from user1", async () => {
		let transaction = await tokenA.approve(shorting.address, 500, {
			from: user1
		});
		assert.ok(
			transaction.logs.find(log => {
				return log.event === "Approval";
			})
		);
	});

	it("approves the shorting contract to withdraw 500 tokenB from user2", async () => {
		let transaction = await tokenB.approve(shorting.address, 500, {
			from: user2
		});
		assert.ok(
			transaction.logs.find(log => {
				return log.event === "Approval";
			})
		);
	});

	it("fills an order for user1 to short 250 tokenB from user2 with 100 tokenA deposit", async () => {
		// Order parameters.
		let lenderAddress = user2;
		let lentAmount = 250;
		let lentToken = tokenB.address;
		let shorterAddress = user1;
		let stakedAmount = 100;
		let stakedToken = tokenA.address;
		let orderExpiration = new Date().getTime() + 600000;
		let shortExpiration = new Date().getTime() + 100000;
		let nonce = 1;

		// Message hash for signing
		let message =
			lenderAddress +
			lentAmount +
			lentToken +
			shorterAddress +
			stakedAmount +
			stakedToken +
			orderExpiration +
			shortExpiration +
			nonce;

		const args = [
			lenderAddress,
			lentAmount,
			lentToken,
			shorterAddress,
			stakedAmount,
			stakedToken,
			orderExpiration,
			shortExpiration,
			nonce
		];
		const argTypes = [
			"address",
			"uint256",
			"address",
			"address",
			"uint256",
			"address",
			"uint256",
			"uint256",
			"uint256"
		];

		const msg = ABI.soliditySHA3(argTypes, args);
    orderHash = util.bufferToHex(msg);
		const sig = web3.eth.sign(lenderAddress, util.bufferToHex(msg));
		const { v, r, s } = util.fromRpcSig(sig);

		let transaction = await shorting.fill(
			lenderAddress,
			lentAmount,
			lentToken,
			shorterAddress,
			stakedAmount,
			stakedToken,
			orderExpiration,
			shortExpiration,
			nonce,
			v,
			util.bufferToHex(r),
			util.bufferToHex(s)
		);

		assert.ok(
			transaction.logs.find(log => {
				return log.event === "Filled";
			})
		);
		assert.equal(await tokenA.balanceOf(shorting.address), 100);
		assert.equal(await tokenB.balanceOf(shorting.address), 250);
		assert.equal(await tokenA.balanceOf(user1), 900);
		assert.equal(await tokenB.balanceOf(user2), 750);
	});

	it("allows user1 to trade the borrowed 250 tokenB as part of the short", async () => {
		let transaction = await shorting.purchase(tokenA.address, orderHash, {
			from: user1
		});
		assert.ok(
		  transaction.logs.find(log => {
		    return log.event === "Traded";
		  })
		)
	});
});
