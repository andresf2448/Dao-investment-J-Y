// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// =============================================================
//                          INTERFACES
// =============================================================

/// @title IGovernanceToken
/// @notice Minimal interface for minting lifecycle operations required by bootstrap contracts.
interface IGovernanceToken {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Mints governance tokens to recipient.
  /// @param to Receiver address.
  /// @param amount Amount to mint.
  function mint(address to, uint256 amount) external;
  /// @notice Permanently disables further minting.
  function finishMinting() external;
  /// @notice Renounces a role for an account.
  /// @param role Role identifier.
  /// @param account Account renouncing role.
  function renounceRole(bytes32 role, address account) external;
}
