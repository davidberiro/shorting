require('babel-polyfill')

var Shorting = artifacts.require("./Shorting.sol");


contract('Shorting', function(accounts) {
  
  const eq = assert.equal.bind(assert)
  const user1 = accounts[0]
  const user2 = accounts[1]


  it("should do something", async function() {

  });

});
