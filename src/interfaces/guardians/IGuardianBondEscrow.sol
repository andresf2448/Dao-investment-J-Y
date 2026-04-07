// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IGuardianBondEscrow {
  function lock(address guardian, uint256 amount) external;
  function refund(address guardian, uint256 amount) external;
  function releaseOnResign(address guardian, uint256 amount) external;
  function slashToTreasury(address guardian, uint256 amount) external;
  function bondedBalance(address guardian) external view returns (uint256);
}