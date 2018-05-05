pragma solidity ^0.4.21;

import "./TokenOracleInterface.sol";
import "./lib/helpers/Ownable.sol";
import "./lib/helpers/SafeMath.sol";
import {StandardToken as ERC20} from "./lib/ERC20/StandardToken.sol";

// TODO remove this afterwards
import "./lib/helpers/Debuggable.sol";

// TODO add multiple admin functionality?
contract TokenOracle is TokenOracleInterface, Ownable, Debuggable {
  using SafeMath for uint256;
  
  uint256 DECIMALS = 18;

  event RateSet(address indexed tokenAddress, uint256 value);
  
  // mapping of token to value
  // value is how much you get for 1 * (10^DECIMALS) `baseToken`
  // e.g.
  // if "cot" is the `baseToken`, then:
  // "bat => 1000 * 10^18" means "1 * (10^DECIMALS) cot == 1000 * 10^18" bat"
  mapping (address => uint256) public tokenValues;

  // we store all the tokens we have prices for too so that we can more easily return data to clients
  address[] tokens;
  // to help us avoid adding duplicate items to the tokens array
  // TODO we could potentially use `tokenValues` for this too if we don't allow rate to be set to 0
  mapping (address => bool) public tokenExists;

  ERC20 public baseToken;

  function TokenOracle(address _baseToken) public {
    baseToken = ERC20(_baseToken);

    // baseToken:baseToken is always 1:1 conversion
    tokenValues[_baseToken] = 1 * (10 ** DECIMALS);

    tokens.push(_baseToken);
    tokenExists[_baseToken] = true;
  }

  // convert from amount of "_from" token to "_to" token
  function convert(ERC20 _from, ERC20 _to, uint256 _amount) public view returns (uint256) {
    // TODO not sure if we throw an error in this case or if we just return 0
    // returning 0 probably makes more sense
    // require(tokenValues[_from] != 0);
    if (tokenValues[_from] == 0)
      return 0;

    if (_amount == 0)
      return 0;

    if (_from == _to)
      return _amount;

    return _amount.mul(tokenValues[_to]).div(tokenValues[_from]);
  }

  function _setRate(ERC20 _token, uint256 _value) internal {
    require(address(_token) != address(baseToken));

    tokenValues[_token] = _value;

    emit RateSet(_token, _value);
    
    if (!tokenExists[_token]) {
      tokens.push(_token);
      tokenExists[_token] = true;
    }
  }

  // TODO disallow setRate to 0?
  function setRate(ERC20 _token, uint256 _value) public onlyOwner {
    _setRate(_token, _value);
  }

  function setMultipleRates(ERC20[] _tokens, uint256[] _values) public onlyOwner {
    for (uint256 i = 0; i < _tokens.length; i++) {
      _setRate(_tokens[i], _values[i]);
    }
  }

  function getAllTokenValues() external view returns(
    address[] addresses,
    uint256[] values
  ) {
    addresses = new address[](tokens.length);
    values = new uint256[](tokens.length);

    for (uint i; i < tokens.length; i++) {
      addresses[i] = tokens[i];
      values[i] = tokenValues[address(tokens[i])];
    }
  }
}
