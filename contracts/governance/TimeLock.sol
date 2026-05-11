// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// =============================================================
//                           IMPORTS
// =============================================================
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title TimeLock
/// @notice Thin wrapper around OpenZeppelin TimelockController for DAO governance execution delays.
contract TimeLock is TimelockController {
  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /// @notice Deploys a timelock controller with predefined proposers/executors/admin.
  /// @param minDelay Minimum delay required before scheduled operations can execute.
  /// @param proposers Addresses allowed to schedule operations.
  /// @param executors Addresses allowed to execute ready operations.
  /// @param admin Initial admin address.
  constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
    TimelockController(minDelay, proposers, executors, admin)
  {}
}
