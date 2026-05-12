// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
  AggregatorV3Interface
} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockV3AggregatorControlled is AggregatorV3Interface {
  uint8 private _decimals;
  int256 private _answer;
  uint80 private _roundId;
  uint80 private _answeredInRound;
  uint256 private _updatedAt;

  constructor(uint8 decimals_, int256 answer_) {
    _decimals = decimals_;
    _answer = answer_;
    _roundId = 1;
    _answeredInRound = 1;
    _updatedAt = block.timestamp;
  }

  function setData(uint8 decimals_, int256 answer_, uint80 roundId_, uint80 answeredInRound_, uint256 updatedAt_)
    external
  {
    _decimals = decimals_;
    _answer = answer_;
    _roundId = roundId_;
    _answeredInRound = answeredInRound_;
    _updatedAt = updatedAt_;
  }

  function decimals() external view override returns (uint8) {
    return _decimals;
  }

  function description() external pure returns (string memory) {
    return "MockV3AggregatorControlled";
  }

  function version() external pure returns (uint256) {
    return 1;
  }

  function getRoundData(uint80)
    external
    view
    override
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    roundId = _roundId;
    answer = _answer;
    startedAt = _updatedAt;
    updatedAt = _updatedAt;
    answeredInRound = _answeredInRound;
  }

  function latestRoundData()
    external
    view
    override
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    roundId = _roundId;
    answer = _answer;
    startedAt = _updatedAt;
    updatedAt = _updatedAt;
    answeredInRound = _answeredInRound;
  }
}
