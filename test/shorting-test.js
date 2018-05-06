require('babel-polyfill')

var Shorting = artifacts.require("./Shorting.sol");
var TokenA = artifacts.require("./lib/tokens/TokenA.sol");
var TokenB = artifacts.require("./lib/tokens/TokenB.sol");

contract('Shorting', function(accounts) {
  
  const eq = assert.equal.bind(assert)
  const owner = accounts[0]
  const user1 = accounts[1]
  const user2 = accounts[2]

  it("should do something", async function() {

  });

});
