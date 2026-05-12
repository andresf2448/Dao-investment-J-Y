// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IStrategyRouter} from "../../contracts/interfaces/execution/IStrategyRouter.sol";

contract MockStrategyRouterNoop is IStrategyRouter {
  uint256 public executeCalls;
  uint256 public divestCalls;

  function executeMultiple(address, address, address[] calldata, uint256[] calldata, uint8) external override {
    executeCalls++;
  }

  function divestMultiple(address, address[] calldata, uint256[] calldata) external override {
    divestCalls++;
  }

  function isAdapterAllowed(address) external pure override returns (bool) {
    return true;
  }

  function getAllowedAdapters() external pure override returns (address[] memory arr) {
    arr = new address[](0);
  }
}
