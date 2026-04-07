// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IRiskManager {
  function validateExecution(
    address vault,
    address asset,
    address adapter,
    bytes calldata data
  ) external view;

  function getValidatedPrice(address asset) external view returns (uint256);

  function isAssetHealthy(address asset) external view returns (bool);
}