// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// =============================================================
//                          INTERFACES
// =============================================================

/// @title IStrategyRouter
/// @notice Router interface used by vaults to execute invest/divest batches.
interface IStrategyRouter {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Executes strategy actions across multiple adapters.
  /// @param vault Vault requesting execution.
  /// @param asset Underlying asset being validated.
  /// @param adapters Adapter list to call.
  /// @param amountsToInvest Amount list aligned with adapters.
  /// @param action Action selector consumed by each adapter.
  function executeMultiple(
    address vault,
    address asset,
    address[] calldata adapters,
    uint256[] calldata amountsToInvest,
    uint8 action
  ) external;

  /// @notice Requests divest operations across adapters.
  /// @param vault Vault requesting divest.
  /// @param adapters Adapter list to call.
  /// @param amountsToDivest Amount list aligned with adapters.
  function divestMultiple(address vault, address[] calldata adapters, uint256[] calldata amountsToDivest) external;

  /// @notice Checks if an adapter is currently allowlisted.
  /// @param adapter Adapter address.
  /// @return True if allowlisted.
  function isAdapterAllowed(address adapter) external view returns (bool);

  /// @notice Returns all allowlisted adapters.
  /// @return Adapter list.
  function getAllowedAdapters() external view returns (address[] memory);
}
