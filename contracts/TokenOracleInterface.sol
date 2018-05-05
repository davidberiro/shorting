pragma solidity ^0.4.18;

import {StandardToken as ERC20} from "./lib/ERC20/StandardToken.sol";

contract TokenOracleInterface {
  function convert(ERC20 _from, ERC20 _to, uint256 _amount) public view returns (uint256);
  function setRate(ERC20 _token, uint256 _value) public;
  function setMultipleRates(ERC20[] _tokens, uint256[] _values) public;
}
