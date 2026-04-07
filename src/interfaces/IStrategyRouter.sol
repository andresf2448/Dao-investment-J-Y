// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IStrategyRouter {
  function execute(
    address adapter,
    address vault,
    address asset,
    bytes calldata data
  ) external;
}