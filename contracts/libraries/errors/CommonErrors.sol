// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                          LIBRARIES
// =============================================================

/// @title CommonErrors
/// @notice Shared custom errors reused across protocol contracts.
library CommonErrors {
  /*//////////////////////////////////////////////////////////////
                                  ERRORS
  //////////////////////////////////////////////////////////////*/
  /// @notice Thrown when a zero address is provided for a required address parameter.
  error ZeroAddress();

  /// @notice Thrown when a zero amount is provided where non-zero is required.
  error ZeroAmount();

  /// @notice Thrown when caller does not satisfy the required authorization.
  error Unauthorized();
}
