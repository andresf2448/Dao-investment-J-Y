// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                          INTERFACES
// =============================================================

/// @title IGuardianBondEscrow
/// @notice Interface for guardian bond custody operations.
interface IGuardianBondEscrow {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Locks a guardian bond amount inside escrow.
  /// @param guardian Guardian address whose bond is locked.
  /// @param amount Amount to lock.
  function lock(address guardian, uint256 amount) external;
  /// @notice Refunds part or all of a guardian bond.
  /// @param guardian Guardian address receiving refund.
  /// @param amount Amount to refund.
  function refund(address guardian, uint256 amount) external;
  /// @notice Releases bond after voluntary guardian resignation.
  /// @param guardian Guardian address receiving released bond.
  /// @param amount Amount to release.
  function releaseOnResign(address guardian, uint256 amount) external;
  /// @notice Slashes guardian bond and forwards it to treasury.
  /// @param guardian Guardian address being slashed.
  /// @param amount Amount to slash.
  function slashToTreasury(address guardian, uint256 amount) external;
}
