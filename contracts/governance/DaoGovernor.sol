// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                           IMPORTS
// =============================================================
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorStorage} from "@openzeppelin/contracts/governance/extensions/GovernorStorage.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import { GovernorVotesQuorumFraction } from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title DaoGovernor
/// @notice Governance module combining voting token logic with timelock-controlled execution.
/// @dev Wraps OpenZeppelin governor extensions with immutable voting parameters set at deployment.
contract DaoGovernor is
  Governor,
  GovernorCountingSimple,
  GovernorStorage,
  GovernorVotes,
  GovernorVotesQuorumFraction,
  GovernorTimelockControl
{
  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @notice Minimum proposal threshold in voting power units.
  uint256 minProposalThreshold;
  /// @notice Voting delay in blocks before proposal becomes active.
  uint48 minVotingDelay;
  /// @notice Voting period in blocks.
  uint32 minVotingPeriod;

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /// @notice Creates the governor with proposal threshold, voting delay, and voting period.
  /// @param governanceToken Votes-enabled governance token.
  /// @param timelock Timelock that queues and executes successful proposals.
  /// @param minProposalThreshold_ Minimum proposal power required to submit.
  /// @param minVotingDelay_ Delay in blocks before voting starts.
  /// @param minVotingPeriod_ Voting duration in blocks.
  constructor(
    IVotes governanceToken,
    TimelockController timelock,
    uint256 minProposalThreshold_,
    uint48 minVotingDelay_,
    uint32 minVotingPeriod_
  )
    Governor("DaoGovernor")
    GovernorVotes(governanceToken)
    GovernorVotesQuorumFraction(4)
    GovernorTimelockControl(timelock)
  {
    minProposalThreshold = minProposalThreshold_;
    minVotingDelay = minVotingDelay_;
    minVotingPeriod = minVotingPeriod_;
  }

  // ==========================================================
  //                           PUBLIC
  // ==========================================================

  /// @inheritdoc Governor
  function votingDelay() public view override returns (uint256) {
    return minVotingDelay;
  }

  /// @inheritdoc Governor
  function votingPeriod() public view override returns (uint256) {
    return minVotingPeriod;
  }

  /// @inheritdoc Governor
  function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
    return super.state(proposalId);
  }

  /// @inheritdoc Governor
  function proposalThreshold() public view override returns (uint256) {
    return minProposalThreshold;
  }

  /// @inheritdoc Governor
  function proposalNeedsQueuing(uint256 proposalId)
    public
    view
    override(Governor, GovernorTimelockControl)
    returns (bool)
  {
    return super.proposalNeedsQueuing(proposalId);
  }

  // ==========================================================
  //                          INTERNAL
  // ==========================================================

  /// @inheritdoc GovernorStorage
  function _propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description,
    address proposer
  ) internal override(Governor, GovernorStorage) returns (uint256) {
    return super._propose(targets, values, calldatas, description, proposer);
  }

  /// @inheritdoc GovernorTimelockControl
  function _queueOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
    return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
  }

  /// @inheritdoc GovernorTimelockControl
  function _executeOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorTimelockControl) {
    super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
  }

  /// @inheritdoc GovernorTimelockControl
  function _cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
    return super._cancel(targets, values, calldatas, descriptionHash);
  }

  /// @inheritdoc GovernorTimelockControl
  function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
    return super._executor();
  }
}
