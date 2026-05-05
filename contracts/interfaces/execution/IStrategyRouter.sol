// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IStrategyRouter {
  function executeMultiple(
    address vault,
    address asset,
    address[] calldata adapters,
    uint256[] calldata amountsToInvest,
    uint8 action
  ) external;

  function divestMultiple(address vault, address[] calldata adapters, uint256[] calldata amountsToDivest) external;

  function isAdapterAllowed(address adapter) external view returns (bool);

  function getAllowedAdapters() external view returns (address[] memory);
}
