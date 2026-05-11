// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                          INTERFACES
// =============================================================

/// @title ICompoundV3Comet
/// @notice Minimal Compound V3 comet interface used by the adapter.
interface ICompoundV3Comet {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Supplies tokens into Compound V3.
  /// @param asset Token to supply.
  /// @param amount Amount to supply.
  function supply(address asset, uint256 amount) external;

  /// @notice Withdraws tokens from Compound V3 to a receiver.
  /// @param to Receiver address.
  /// @param asset Token to withdraw.
  /// @param amount Amount to withdraw.
  function withdrawTo(address to, address asset, uint256 amount) external;

  /// @notice Returns comet base balance for account.
  /// @param account Account address.
  /// @return Base balance.
  function balanceOf(address account) external view returns (uint256);

  /// @notice Returns tracked deposits for user and asset.
  /// @param user User account.
  /// @param asset Token address.
  /// @return Deposited amount.
  function deposits(address user, address asset) external view returns (uint256);
}
