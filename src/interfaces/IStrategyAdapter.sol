// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IStrategyAdapter {
  function execute(address vault, bytes calldata data) external;
}