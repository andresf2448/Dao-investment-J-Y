// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                          INTERFACES
// =============================================================

/// @title IVault
/// @notice Initialization interface for vault clones.
interface IVault {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Initializes vault clone state.
  /// @param asset_ Underlying asset.
  /// @param name_ Vault share token name.
  /// @param symbol_ Vault share token symbol.
  /// @param guardian_ Guardian with strategy permissions.
  /// @param admin_ Timelock/admin address.
  /// @param factory_ Vault factory address.
  /// @param router_ Strategy router address.
  /// @param core_ Protocol core address.
  function initialize(
    address asset_,
    string memory name_,
    string memory symbol_,
    address guardian_,
    address admin_,
    address factory_,
    address router_,
    address core_
  ) external;
}
