pragma solidity ^0.4.18;

import "./lib/ERC20/ERC20.sol";
import "./lib/helpers/Ownable.sol";

contract Shorting is Ownable {
  
  address private thisAddress = address(this);
  
  // struct representing a short between lender and shorter
  struct Short {
    address shorter;
    address lender;
    ERC20 lentToken;
    ERC20 boughtToken;
    ERC20 stakedToken;
    uint256 lentAmount;
    uint256 stakedAmount;
    uint256 boughtAmount;
    uint256 shortExpiration;
  }
  
  // Mapping of order hash to bool (true = short position was closed)
  mapping (bytes32 => bool) public closedShorts;
  // Mapping of order hash to Short struct
  mapping (bytes32 => Short) public shorts;
  
  /*
  * fills an order and creates a short without validating the order
  * (for development purposes, in production would have to verify like AirSwap)  
  */
  function fill(address lenderAddress, uint256 lentAmount, address lentToken,
                address shorterAddress, uint256 stakedAmount, address stakedToken,
                uint256 orderExpiration, uint256 shortExpiration)
                public payable {
                  
    // checking that the order hasnt expired
    require(now < expiration);
    // create hash of the order to store it and validate the order (not yet)
    bytes32 hash = validate(lenderAddress, lentAmount, lentToken, shorterAddress,
                            stakedAmount, stakedToken);
    // assert that all the required tokens were transferred to this contract
    assert(acquire(lenderAddress, lentAmount, lentToken, shorterAddress,
                      stakedAmount, stakedToken));
    
    shorts[hash] = Short(shorterAddress, lenderAddress, lentToken, null, stakedToken,
                        lentAmount, stakedAmount, 0, shortExpiration);
    
  }
  
  /*
  * transfers the lent amount of ERC20 token and staked amount of ERC20 token
  * to this contract  
  */
  function acquire(address lenderAddress, uint256 lentAmount, address lentToken,
                      address shorterAddress, uint256 stakedAmount, address stakedToken)
                      private returns (bool) {
    return (transfer(lenderAddress, thisAddress, lentAmount, lentToken) &&
            transfer(shorterAddress, thisAddress, stakedAmount, stakedToken));
                        
  }
  
  /*  
  * validates order arguments, should also receive signature of lender
  * but for testing purposes this will do. In production should receive
  * some signatures of order and nonce
  */
  function validate(address lenderAddress, uint256 lentAmount, address lentToken,
                      address shorterAddress, uint256 stakedAmount, address stakedToken)
                      private returns (bytes32) {
    
    bytes32 hashV = keccak256(lenderAddress, lentAmount, lentToken, shorterAddress,
                              stakedAmount, stakedToken);
    return hashV;
  }

  
  function transfer(address from, address to, uint amount, address token) private returns (bool) {
      require(ERC20(token).transferFrom(from, to, amount));
      return true;
  }
  
  // fills an order by verifying it (TODO), 
  /* function fill(address lenderAddress, uint256 lentAmount, address lentToken,
                address shorterAddress, uint256 stakedAmount, address stakedToken,
                uint256 expiration, uint256 nonce, uint8 v, bytes32 r, bytes32 s) payable {
  } */


}