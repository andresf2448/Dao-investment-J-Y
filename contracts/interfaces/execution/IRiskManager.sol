// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IRiskManager {
  function validateExecution(address asset) external view;

  function getValidatedPrice(address asset) external view returns (uint256);

  function isAssetHealthy(address asset) external view returns (bool);
}
