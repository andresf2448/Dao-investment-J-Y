// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IGovernanceToken {
  function mint(address to, uint256 amount) external;
  function finishMinting() external;
  function renounceRole(bytes32 role, address account) external;
}