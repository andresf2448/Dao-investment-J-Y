// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// =============================================================
//                          INTERFACES
// =============================================================

/// @title IRiskManager
/// @notice Interface for risk validation and pricing checks.
interface IRiskManager {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Reverts when execution for asset does not satisfy risk policy.
  /// @param asset Asset to validate.
  function validateExecution(address asset) external view;

  /// @notice Returns latest validated normalized price for an asset.
  /// @param asset Asset to query.
  /// @return Normalized price with 18 decimals.
  function getValidatedPrice(address asset) external view returns (uint256);

  /// @notice Returns whether asset currently passes health checks.
  /// @param asset Asset to query.
  /// @return True when healthy under current policy.
  function isAssetHealthy(address asset) external view returns (bool);
}
