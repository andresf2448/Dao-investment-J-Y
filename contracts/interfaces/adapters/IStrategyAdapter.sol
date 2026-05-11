// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                          INTERFACES
// =============================================================

/// @title IStrategyAdapter
/// @notice Interface used by the router to execute strategy actions on external venues.
interface IStrategyAdapter {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Executes an invest/divest action for a vault.
  /// @param vault Vault address whose funds are being moved.
  /// @param action Action selector (implementation-defined, typically invest/divest).
  /// @param amount Amount of asset to process.
  function execute(address vault, uint8 action, uint256 amount) external;

  /// @notice Returns total underlying assets currently managed for a vault.
  /// @param vault Vault address.
  /// @param asset Asset being accounted.
  /// @return Amount currently deposited through this adapter.
  function totalAssets(address vault, address asset) external view returns (uint256);

  /// @notice Returns the external pool/protocol address used by this adapter.
  /// @return Pool contract address.
  function poolAddress() external view returns (address);
}
