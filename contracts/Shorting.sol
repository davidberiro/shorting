
pragma solidity ^0.4.18;
import {StandardToken as ERC20} from "./lib/ERC20/StandardToken.sol";
import "./lib/kyber/KyberNetworkInterface.sol";
import "./TokenOracleInterface.sol";
import "./lib/helpers/Ownable.sol";

/*
* assumes shorter and lender have approved this contract to access their balances
* maybe instead the lender will have to deposit directly to this contract with
* the lending conditions, will figure that out later  
*/
contract Shorting is Ownable {
  
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
  
  event Failed();
  
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
    require(now < orderExpiration);
    
    // create hash of the order to store it and validate the order
    bytes32 hashV = validate(lenderAddress, lentAmount, lentToken, shorterAddress,
                            stakedAmount, stakedToken, orderExpiration, shortExpiration,
                            nonce, v, r, s);
    
    // assert that all the required tokens were transferred to this contract
    assert(acquire(lenderAddress, lentAmount, lentToken, shorterAddress, stakedAmount, stakedToken));
    
    // creating key for short via the hash of the order in shorts mapping
    shorts[hashV] = Short(shorterAddress, lenderAddress, lentToken, 0, stakedToken,
                         lentAmount, stakedAmount, 0, shortExpiration);
                         
    Filled(lenderAddress, lentAmount, lentToken, shorterAddress, stakedAmount, stakedToken, shortExpiration, hashV);
    
  }
  
  function purchase(ERC20 dest, bytes32 orderHash) public {
    // only the shorter can trade the borrowed tokens
    require(msg.sender == shorts[orderHash].shorter);
    
    // require that the shorter hasn't bought any tokens yet
    require(shorts[orderHash].boughtAmount == 0);
    
    ERC20 src = ERC20(shorts[orderHash].lentToken);
    uint srcAmount = shorts[orderHash].lentAmount;
    
    // approve the trade and do it (TODO)
    src.approve(kyberNetwork, srcAmount);
    
    uint256 receivedAmount = kyberNetwork.trade(src, srcAmount, dest, thisAddress, 0, 0, 0);
    shorts[orderHash].boughtToken = dest;
    shorts[orderHash].boughtAmount = receivedAmount;
    Traded();
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
      return;
    }
    
    // if the lender wants to close the position, check if the time expired
    // or that the losses are too much
    if (msg.sender == shorts[orderHash].lender) {
      
      // if the expiration has passed, liquidate the position
      if (now > shorts[orderHash].shortExpiration) {
          return liquidate(orderHash, msg.sender);
      }
      
      // if the lender can liquidate the position because of the shorters losses
      if (lenderCanLiquidate(orderHash)) {
        return liquidate(orderHash, msg.sender);
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