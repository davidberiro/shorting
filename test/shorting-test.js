require('babel-polyfill')

var Shorting = artifacts.require("./Shorting.sol");
var TokenA = artifacts.require("./lib/tokens/TokenA.sol");
var TokenB = artifacts.require("./lib/tokens/TokenB.sol");

contract('Shorting', async (accounts) => {
  
  const eq = assert.equal.bind(assert)
  const owner = accounts[0]
  const user1 = accounts[1]
  const user2 = accounts[2]
  
  let shorting
  let tokenA
  let tokenB

  it("deploys Shorting contract", async () => {
    shorting = await Shorting.deployed()
  });
  
  it("should transfer 1000 tokenA to user1", async () => {
    tokenA = await TokenA.deployed()
    await tokenA.create(user1, 1000)
    let user1balance = await tokenA.balanceOf(user1)
    eq(user1balance, 1000)
  })
  it("should transfer 1000 tokenB to user2", async () => {
    tokenB = await TokenB.deployed()
    await tokenB.create(user2, 1000)
    let user2balance = await tokenB.balanceOf(user2)
    eq(user2balance, 1000)
  })

});
