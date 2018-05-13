pragma solidity ^0.4.21;
import {StandardToken as ERC20} from "./lib/ERC20/StandardToken.sol";
import "./lib/kyber/KyberNetworkInterface.sol";
import "./TokenOracleInterface.sol";
import "./lib/helpers/Ownable.sol";
import "./lib/helpers/SafeMath.sol";

/*
* assumes shorter and lender have approved this contract to access their balances
* maybe instead the lender will have to deposit directly to this contract with
* the lending conditions, will figure that out later  
*/
contract Shorting is Ownable {
  using SafeMath for uint256;
  
  address private thisAddress = address(this);

  KyberNetworkInterface public kyberNetwork;
  TokenOracleInterface public tokenOracle;
  // address to send profits to
  address private ownersAddress;
  
  // struct representing a short between lender and shorter
  struct Short {
    address shorter;
    address lender;
    address lentToken;
    address boughtToken;
    address stakedToken;
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
  event Filled(address lender, uint256 lentAmount, address lentToken, address shorter, uint256 stakedAmount, address stakedToken, uint256 expiration, bytes32 hash);
  event Cancelled();
  event Traded();
  event Liquidated();
  
  /* Event emitted when something fails
  *  Error codes:
  *  1-> 'The order has expired'
  *  2-> 
  *
  *
  *
  *
  */
  event Failed(uint code, address lender, address lentToken, uint256 lentAmount, 
              address shorter, address stakedToken, uint256 stakedAmount,
              uint256 orderExpiration, uint256 shortExpiration, uint256 nonce);
  
  function Shorting(address _kyberNetworkAddress, address _tokenOracleAddress) public {
    kyberNetwork = KyberNetworkInterface(_kyberNetworkAddress);
    tokenOracle = TokenOracleInterface(_tokenOracleAddress);
    ownersAddress = msg.sender;
  }
  
  /*
  * fills an order and creates a short position  
  */
  function fill(address lenderAddress, uint256 lentAmount, address lentToken,
                address shorterAddress, uint256 stakedAmount, address stakedToken,
                uint256 orderExpiration, uint256 shortExpiration, uint256 nonce,
                uint8 v, bytes32 r, bytes32 s) public payable {
                  
    // checking that the order hasnt expired
    if (now > orderExpiration) {
      Failed(1, lenderAddress, lentToken, lentAmount, shorterAddress, stakedToken,
            stakedAmount, orderExpiration, shortExpiration, nonce);
      return;
    }
    
    // create hash of the order to store it and validate the order
    bytes32 hashV = validate(lenderAddress, lentAmount, lentToken, shorterAddress,
                            stakedAmount, stakedToken, orderExpiration, shortExpiration,
                            nonce, v, r, s);
    
    // assert that all the required tokens were transferred to this contract
    assert(acquire(lenderAddress, lentAmount, lentToken, shorterAddress, stakedAmount, stakedToken));
    
    // creating key for short via the hash of the order in shorts mapping
    shorts[hashV] = Short(shorterAddress, lenderAddress, lentToken, 0, stakedToken,
                         lentAmount, stakedAmount, 0, shortExpiration);
    closedShorts[hashV] = false;
                         
    emit Filled(lenderAddress, lentAmount, lentToken, shorterAddress, stakedAmount, stakedToken, shortExpiration, hashV);
    
  }
  
  function purchase(ERC20 dest, bytes32 orderHash) public {
    // only the shorter can trade the borrowed tokens
    require(msg.sender == shorts[orderHash].shorter);
    
    // require that the shorter hasn't bought any tokens yet
    require(shorts[orderHash].boughtAmount == 0);
    
    ERC20 src = ERC20(shorts[orderHash].lentToken);
    uint srcAmount = shorts[orderHash].lentAmount;
    
    // approve the trade and do it
    src.approve(kyberNetwork, srcAmount);
    
    uint256 receivedAmount = kyberNetwork.trade(src, srcAmount, dest, thisAddress, 0, 0, 0);
    shorts[orderHash].boughtToken = dest;
    shorts[orderHash].boughtAmount = receivedAmount;
    emit Traded();
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
    
    // require that the short position exists (is this necessary?)
    /* require(shorts[orderHash] != 0); */
    
    // allow shorter to close the position whenever they want
    if (msg.sender == shorts[orderHash].shorter) {
      liquidate(orderHash, msg.sender);
      closedShorts[orderHash] = true;
      return;
    }
    
    // if the lender wants to close the position, check if the time expired
    // or that the losses are too much
    if (msg.sender == shorts[orderHash].lender) {
      
      // if the expiration has passed, liquidate the position
      if (now > shorts[orderHash].shortExpiration) {
          liquidate(orderHash, msg.sender);
          closedShorts[orderHash] = true;
          return;
      }
      
      // if the lender can liquidate the position because of the shorters losses
      if (lenderCanLiquidate(orderHash)) {
        liquidate(orderHash, msg.sender);
        closedShorts[orderHash] = true;
        return;
      }
    }
    
    // TODO allow public to close position if certain threshold is reached
        
  }
  
  /*
  * converts the boughtToken into lentToken, and if it's not enough to cover the
  * lent amount also converts the stakedToken into lentToken (note that in the dy
  * dx protocol stakedToken must also be boughtToken, perhaps we will implement
  * that too), repays the lender (lending fee was payed before? or maybe interest
  * will be payed now). Whatever is left over is returned to the shorter, and
  * perhaps if the shorter makes a profit we take a cut
  * note that the liquidator argument is needed for the Liquidated event
  * so that we know who called it
  */
  function liquidate(bytes32 orderHash, address liquidator) private {
    // Actual implementation of this function should take more factors into
    // consideration, but for development purposes this will do. The main issue
    // is that if the bought tokens price decreases relative to the lent token,
    // even by just a little do we really have to convert all of the staked token 
    // into lent token in order to repay the lender? food for thought...
    // making me reconsider a bit of the foundation of the contract
    ERC20 boughtToken = ERC20(shorts[orderHash].boughtToken);
    ERC20 stakedToken = ERC20(shorts[orderHash].stakedToken);
    ERC20 lentToken = ERC20(shorts[orderHash].lentToken);
    uint boughtAmount = shorts[orderHash].boughtAmount;
    uint stakedAmount = shorts[orderHash].stakedAmount;
    uint lentAmount = shorts[orderHash].lentAmount;
    address lender = shorts[orderHash].lender;
    address shorter = shorts[orderHash].shorter;
    
    boughtToken.approve(kyberNetwork, boughtAmount);
    uint256 receivedAmount = kyberNetwork.trade(boughtToken, boughtAmount, lentToken, thisAddress, 0, 0, 0);
    
    // If the shorter made a profit
    if (receivedAmount >= lentAmount) {
      // Return all the staked tokens
      stakedToken.transfer(shorter, uint256(stakedAmount));
      // Send the converted lent token profit to the shorter
      // threw an error since standardtoken cant send 0 coins
      if (receivedAmount - lentAmount > 0) {
        lentToken.transfer(shorter, receivedAmount - lentAmount);        
      }
      // Send the lent amount back to the lender (when does he take a fee?)
      lentToken.transfer(lender, uint256(lentAmount));
      
    }
    
    else {
      uint256 loss = uint256(lentAmount).sub(receivedAmount);
      // Convert staked token into lent token to cover loss
      stakedToken.approve(kyberNetwork, stakedAmount);
      uint256 received = kyberNetwork.trade(stakedToken, stakedAmount, lentToken, thisAddress, 0, 0, 0);
      if (received.add(receivedAmount) < lentAmount) {
        // Fatal error, lender cannot lose money, what do we do here..?
        lentToken.transfer(lender, received.add(receivedAmount));
        return;
      }
      uint256 leftOver = received.add(receivedAmount).sub(lentAmount);
      lentToken.transfer(shorter, leftOver);
      lentToken.transfer(lender, lentAmount);
    }
    
    emit Liquidated();
    
  }
  
  /*
  * checks if the short position can be liquidated by the lender, must check
  * the conversion rate of the boughtToken and stakedToken into lentToken
  * and see if a certain threshold is passed  
  */
  function lenderCanLiquidate(bytes32 orderHash) private returns (bool) {
    
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
  * validates order arguments for fill function using lenders signature
  */
  function validate(address lenderAddress, uint256 lentAmount, address lentToken,
                    address shorterAddress, uint256 stakedAmount, address stakedToken,
                    uint256 orderExpiration, uint256 shortExpiration, uint256 nonce,
                    uint8 v, bytes32 r, bytes32 s) private returns (bytes32) {
    
    // create hash from the order details, should add nonce at the end (TODO)
    bytes32 hashV = keccak256(lenderAddress, lentAmount, lentToken, shorterAddress, stakedAmount, stakedToken, orderExpiration, shortExpiration, nonce);
    
    bytes memory prefix = "\x19Ethereum Signed Message:\n32";    
    bytes32 prefixedHash = sha3(prefix, hashV);
    require(ecrecover(prefixedHash, v, r, s) == lenderAddress);

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
  
}