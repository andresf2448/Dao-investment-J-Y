// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                          INTERFACES
// =============================================================

/// @title IGuardianAdministrator
/// @notice Minimal interface for querying guardian activity status.
interface IGuardianAdministrator {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Indicates whether guardian is currently active.
  /// @param guardian Guardian address to query.
  /// @return True if guardian is active.
  function isActiveGuardian(address guardian) external view returns (bool);
}
