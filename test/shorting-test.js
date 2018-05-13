require("babel-polyfill");
const util = require("ethereumjs-util");
const jsutil = require("./util.js");
const ABI = require("ethereumjs-abi");

var Shorting = artifacts.require("./Shorting.sol");
var TokenA = artifacts.require("./lib/tokens/TokenA.sol");
var TokenB = artifacts.require("./lib/tokens/TokenB.sol");
var TokenOracle = artifacts.require("./TokenOracle.sol");
var KyberNetwork = artifacts.require("./lib/kyber/KyberNetwork.sol");

contract("Shorting", async accounts => {
	// This only runs once across all test suites
	before(() => jsutil.measureGas(accounts));
	after(() => jsutil.measureGas(accounts));

	const eq = assert.equal.bind(assert);

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
	
	async function fillShort(			
				lenderAddress,
				lentAmount,
				lentToken,
				shorterAddress,
				stakedAmount,
				stakedToken,
				orderExpiration,
				shortExpiration,
				nonce
			) {
	
		shorting = await Shorting.deployed()
		
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


	}

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
		eq(await tokenA.balanceOf(user1), 1000);
	});

	it("deploys tokenB and transfers 1000 tokenB to user2", async () => {
		tokenB = await TokenB.deployed();
		await tokenB.create(user2, 1000);
		eq(await tokenB.balanceOf(user2), 1000);
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

	it("deploys KyberNetwork and deposits 10000 token A and B into it", async () => {
		kyberNetwork = await KyberNetwork.deployed();
		await tokenA.create(kyberNetwork.address, 10000);
		await tokenB.create(kyberNetwork.address, 10000);
		eq(await tokenA.balanceOf(kyberNetwork.address), 10000);
		eq(await tokenB.balanceOf(kyberNetwork.address), 10000);
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
		
		await fillShort(lenderAddress, lentAmount, lentToken, shorterAddress, stakedAmount,
			 							stakedToken, orderExpiration, shortExpiration, nonce)
		
		
		eq(await tokenA.balanceOf(shorting.address), 100);
		eq(await tokenB.balanceOf(shorting.address), 250);
		eq(await tokenA.balanceOf(user1), 900);
		eq(await tokenB.balanceOf(user2), 750);
	});

	it("allows user1 to trade the borrowed 250 tokenB as part of the short", async () => {
		let transaction = await shorting.purchase(tokenA.address, orderHash, {
			from: user1
		});
		assert.ok(
			transaction.logs.find(log => {
				return log.event === "Traded";
			})
		);
		eq(await tokenA.balanceOf(shorting.address), 350);
		eq(await tokenB.balanceOf(shorting.address), 0);
	});

	it("liquidates the position with the same 1-1 rate of A to B", async () => {
		let transaction = await shorting.closePosition(orderHash, { from: user1 });
		assert.ok(
			transaction.logs.find(log => {
				return log.event === "Liquidated";
			})
		);
		eq(await tokenA.balanceOf(user1), 1000);
		eq(await tokenB.balanceOf(user2), 1000);
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
		
		await fillShort(lenderAddress, lentAmount, lentToken, shorterAddress, stakedAmount,
										stakedToken, orderExpiration, shortExpiration, nonce)

		eq(await tokenA.balanceOf(shorting.address), 100);
		eq(await tokenB.balanceOf(shorting.address), 250);
		eq(await tokenA.balanceOf(user1), 900);
		eq(await tokenB.balanceOf(user2), 750);
	});

	it("allows user1 to trade the borrowed 250 tokenB as part of the short", async () => {
		let transaction = await shorting.purchase(tokenA.address, orderHash, {
			from: user1
		});
		assert.ok(
			transaction.logs.find(log => {
				return log.event === "Traded";
			})
		);
		eq(await tokenA.balanceOf(shorting.address), 350);
		eq(await tokenB.balanceOf(shorting.address), 0);
	});

	it("liquidates the position with 1-2 rate of A to B", async () => {
		await tokenOracle.setRate(tokenB.address, 2 * Math.pow(10, 18));
		let transaction = await shorting.closePosition(orderHash, { from: user1 });
		assert.ok(
			transaction.logs.find(log => {
				return log.event === "Liquidated";
			})
		);
		eq(await tokenA.balanceOf(user1), 1000);
		eq(await tokenB.balanceOf(user1), 250);
		eq(await tokenB.balanceOf(user2), 1000);
	});
});
