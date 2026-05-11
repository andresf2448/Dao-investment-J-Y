// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// =============================================================
//                          INTERFACES
// =============================================================

/// @title IProtocolCore
/// @notice Core protocol read interface consumed by factories, vaults, and treasury.
interface IProtocolCore {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Returns whether an asset is supported for vault creation.
  /// @param asset Asset address to query.
  /// @return True if supported.
  function isVaultAssetSupported(address asset) external view returns (bool);
  /// @notice Returns whether vault creation is globally paused.
  /// @return True if paused.
  function isVaultCreationPaused() external view returns (bool);
  /// @notice Returns whether vault deposits are globally paused.
  /// @return True if paused.
  function isVaultDepositsPaused() external view returns (bool);
  /// @notice Returns whether token is part of approved genesis token set.
  /// @param token Token address to query.
  /// @return True if token is approved as genesis token.
  function hasGenesisToken(address token) external view returns (bool);
}
