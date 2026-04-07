// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IVaultStrategyExecutor {
  function executeFromRouter(
    address target,
    uint256 value,
    bytes calldata data
  ) external returns(bytes memory result);

  function approveTokenFromRouter(
    address token,
    address spender,
    uint256 amount
  ) external;
}