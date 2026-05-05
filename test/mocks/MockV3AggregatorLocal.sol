// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {
  AggregatorV3Interface
} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockV3AggregatorLocal is AggregatorV3Interface {
  uint8 private _decimals;
  int256 private _answer;
  uint80 private _roundId;

  constructor(uint8 decimals_, int256 answer_) {
    _decimals = decimals_;
    _answer = answer_;
    _roundId = 1;
  }

  function latestAnswer() external view returns (int256) {
    return _answer;
  }

  function latestTimestamp() external view returns (uint256) {
    return block.timestamp;
  }

  function latestRound() external view returns (uint256) {
    return _roundId;
  }

  function getAnswer(uint256) external view returns (int256) {
    return _answer;
  }

  function getTimestamp(uint256) external view returns (uint256) {
    return block.timestamp;
  }

  function decimals() external view override returns (uint8) {
    return _decimals;
  }

  function description() external pure returns (string memory) {
    return "MockV3AggregatorLocal";
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
    startedAt = block.timestamp;
    updatedAt = block.timestamp;
    answeredInRound = _roundId;
  }

  function latestRoundData()
    external
    view
    override
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    roundId = _roundId;
    answer = _answer;
    startedAt = block.timestamp;
    updatedAt = block.timestamp;
    answeredInRound = _roundId;
  }

  function setAnswer(int256 answer_) external {
    _answer = answer_;
    _roundId++;
  }

  function setDecimals(uint8 decimals_) external {
    _decimals = decimals_;
  }
}
