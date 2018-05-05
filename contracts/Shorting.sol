pragma solidity ^0.4.18;

import {StandardToken as ERC20} from "./lib/ERC20/StandardToken.sol";

/*
* assumes shorter and lender have approved this contract to access their balances  
*/
contract Shorting {
  
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
  
  // mapping of order hash to bool (true = short position was closed)
  mapping (bytes32 => bool) public closedShorts;
  // mapping of order hash to Short struct
  mapping (bytes32 => Short) public shorts;
  
  // Events that are emitted in certain scenarios (TODO)
  event Filled();
  event Cancelled();
  event Liquidated();
  
  /*
  * fills an order and creates a short position without validating the order
  * (for development purposes, in production would have to verify like AirSwap)  
  */
  function fill(address lenderAddress, uint256 lentAmount, address lentToken,
                address shorterAddress, uint256 stakedAmount, address stakedToken,
                uint256 orderExpiration, uint256 shortExpiration)
                public payable {
                  
    // checking that the order hasnt expired
    require(now < orderExpiration);
    
    // create hash of the order to store it and validate the order (not yet)
    bytes32 hash = validate(lenderAddress, lentAmount, lentToken, shorterAddress,
                            stakedAmount, stakedToken);
    
    // assert that all the required tokens were transferred to this contract
    assert(acquire(lenderAddress, lentAmount, lentToken, shorterAddress,
                   stakedAmount, stakedToken));
    
    // creating hash in shorts mapping
    shorts[hash] = Short(shorterAddress, lenderAddress, lentToken, null, stakedToken,
                         lentAmount, stakedAmount, 0, shortExpiration);
    
  }
  
  /*
  * closes and liquidates the short position, can be called any time by the
  * shorter, or if the staked amount can only cover < 50% of the losses caused
  * by buying the boughtToken it can be called by the lender. Maybe will allow option
  * for position to be closed by the public for a small reward if the staked amount
  * can cover less than a certain percentage of losses
  */
  function closePosition(bytes32 orderHash) public {
    
    // require that the position hasn't already been closed
    require(!closedShorts[orderHash]);    
  }
  
  /*
  * converts the boughtToken into lentToken, and if it's not enough to cover the
  * lent amount also converts the stakedToken into lentToken (note that in the dy
  * dx protocol stakedToken must also be boughtToken, perhaps we will implement
  * that too), repays the lender (lending fee was payed before? or maybe interest
  * will be payed now). Whatever is left over is returned to the shorter, and
  * perhaps if the shorter makes a profit we take a cut
  */
  function liquidate(bytes32 orderHash) private {
    
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
    
    // create hash from the order details, should add nonce at the end (TODO)
    bytes32 hashV = keccak256(lenderAddress, lentAmount, lentToken, shorterAddress, stakedAmount, stakedToken);
    
    return hashV;
  }

  /*  
  * transfers ERC20 tokens and returns true upon success
  */
  function transfer(address from, address to, uint amount, address token) 
                    private returns (bool) {
      
      require(ERC20(token).transferFrom(from, to, amount));
      return true;
  }
  
  // fills an order by verifying it (TODO), 
  /* function fill(address lenderAddress, uint256 lentAmount, address lentToken,
                address shorterAddress, uint256 stakedAmount, address stakedToken,
                uint256 expiration, uint256 nonce, uint8 v, bytes32 r, bytes32 s) payable {
  } */


}