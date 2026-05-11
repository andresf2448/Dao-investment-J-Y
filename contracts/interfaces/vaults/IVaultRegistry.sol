// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// =============================================================
//                          INTERFACES
// =============================================================

/// @title IVaultRegistry
/// @notice Registry interface for vault registration and activity queries.
interface IVaultRegistry {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Registers a vault and guardian/asset mapping.
  /// @param vault Vault address.
  /// @param guardian Guardian address.
  /// @param asset Underlying asset.
  function registerVault(address vault, address guardian, address asset) external;

  /// @notice Returns vault for guardian/asset pair.
  /// @param asset Underlying asset.
  /// @param guardian Guardian address.
  /// @return Vault address or zero.
  function getVaultByAssetAndGuardian(address asset, address guardian) external view returns (address);

  /// @notice Returns active state of a vault.
  /// @param vault Vault address.
  /// @return True if vault is active.
  function isActiveVault(address vault) external view returns (bool);
}
