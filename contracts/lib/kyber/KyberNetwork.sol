pragma solidity ^0.4.19;

import "./KyberNetworkInterface.sol";
import "../../TokenOracleInterface.sol";
import "../helpers/Ownable.sol"; 

contract KyberNetwork is KyberNetworkInterface, Ownable {
  TokenOracleInterface public tokenOracle;

  function KyberNetwork(address _tokenOracle) public {
    tokenOracle = TokenOracleInterface(_tokenOracle);
  }

  function setTokenOracle(address _tokenOracle) public onlyOwner {
    tokenOracle = TokenOracleInterface(_tokenOracle);
  }

  function trade(
    ERC20 src,
    uint srcAmount,
    ERC20 dest,
    address destAddress,
    uint maxDestAmount,
    uint minConversionRate,
    address walletId
  )
    public
    payable
    returns(uint)
  {
    uint256 destAmount = tokenOracle.convert(src, dest, srcAmount);

    src.transferFrom(msg.sender, this, srcAmount);
    dest.transfer(destAddress, destAmount);
    
    return destAmount;
  }

  function findBestRate(ERC20 src, ERC20 dest, uint srcQty) public view returns(uint, uint) {
    uint bestReserve = 1;
    uint bestRate = 100;
    
    return (bestReserve, bestRate);
  }
    
  function getExpectedRate(ERC20 src, ERC20 dest, uint srcQty) public view returns (uint expectedRate, uint slippageRate) {
    expectedRate = 100;
    slippageRate = 1;
  }
}