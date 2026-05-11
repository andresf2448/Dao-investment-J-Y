// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                          INTERFACES
// =============================================================

/// @title IAaveV3Pool
/// @notice Minimal Aave V3 pool interface used by the adapter.
interface IAaveV3Pool {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Supplies tokens to Aave.
  /// @param asset Token to supply.
  /// @param amount Amount to supply.
  /// @param onBehalfOf Beneficiary account.
  /// @param referralCode Referral code used by Aave.
  function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

  /// @notice Withdraws supplied tokens from Aave.
  /// @param asset Token to withdraw.
  /// @param amount Amount to withdraw.
  /// @param to Receiver address.
  /// @return Amount actually withdrawn.
  function withdraw(address asset, uint256 amount, address to) external returns (uint256);

  /// @notice Returns tracked deposits for user and asset.
  /// @param user User account.
  /// @param asset Token address.
  /// @return Deposited amount.
  function deposits(address user, address asset) external view returns (uint256);
}
