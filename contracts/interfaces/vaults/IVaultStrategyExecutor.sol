// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                          INTERFACES
// =============================================================

/// @title IVaultStrategyExecutor
/// @notice Executor callbacks used by adapters through the router.
interface IVaultStrategyExecutor {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Executes an arbitrary call from router context.
  /// @param target Target contract.
  /// @param value Native token value to send.
  /// @param data Encoded call data.
  /// @return result Return data from target call.
  function executeFromRouter(address target, uint256 value, bytes calldata data)
    external
    returns (bytes memory result);

  /// @notice Updates token allowance from vault to spender under router authority.
  /// @param token ERC20 token to approve.
  /// @param spender Spender address.
  /// @param amount New allowance amount.
  function approveTokenFromRouter(address token, address spender, uint256 amount) external;
}
