// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IStrategyAdapter} from "../../contracts/interfaces/adapters/IStrategyAdapter.sol";

contract MockStrategyAdapter is IStrategyAdapter {
  uint256 public executeCalls;
  address public lastVault;
  uint8 public lastAction;
  uint256 public lastAmount;
  address public immutable pool;
  uint256 public reportedAssets;

  constructor(address pool_) {
    pool = pool_;
  }

  function setReportedAssets(uint256 amount) external {
    reportedAssets = amount;
  }

  function execute(address vault, uint8 action, uint256 amount) external override {
    executeCalls++;
    lastVault = vault;
    lastAction = action;
    lastAmount = amount;
  }

  function totalAssets(address, address) external view override returns (uint256) {
    return reportedAssets;
  }

  function poolAddress() external view override returns (address) {
    return pool;
  }
}
