// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorStorage} from "@openzeppelin/contracts/governance/extensions/GovernorStorage.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DaoGovernor is 
  Governor,
  GovernorCountingSimple,
  GovernorStorage,
  GovernorVotes,
  GovernorVotesQuorumFraction,
  GovernorTimelockControl
{
  uint256 minProposalThreshold;
  uint48 minVotingDelay;
  uint32 minVotingPeriod; 

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

  function votingDelay() public view override returns(uint256) {
    return minVotingDelay;
  }

  function votingPeriod() public view override returns(uint256) {
    return minVotingPeriod;
  }

  function state(uint256 proposalId)
    public
    view
    override(Governor, GovernorTimelockControl)
    returns(ProposalState)
  {
    return super.state(proposalId);
  }

  function proposalThreshold()
    public
    view
    override
    returns(uint256)
  {
    return minProposalThreshold;
  }

  function proposalNeedsQueuing(uint256 proposalId)
    public
    view
    override(Governor, GovernorTimelockControl)
    returns(bool)
  {
    return super.proposalNeedsQueuing(proposalId);
  }

  function _propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description,
    address proposer
  )
    internal
    override(Governor, GovernorStorage)
    returns(uint256)
  {
    return super._propose(
      targets,
      values,
      calldatas,
      description,
      proposer
    );
  }

  function _queueOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  )
    internal
    override(Governor, GovernorTimelockControl)
    returns(uint48)
  {
    return super._queueOperations(
      proposalId,
      targets,
      values,
      calldatas,
      descriptionHash
    );
  }

  function _executeOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  )
    internal
    override(Governor, GovernorTimelockControl)
  {
    super._executeOperations(
      proposalId,
      targets,
      values,
      calldatas,
      descriptionHash
    );
  }

  function _cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  )
    internal
    override(Governor, GovernorTimelockControl)
    returns(uint256)
  {
    return super._cancel(
      targets,
      values,
      calldatas,
      descriptionHash
    );
  }

  function _executor()
    internal
    view
    override(Governor,GovernorTimelockControl)
    returns(address)
  {
    return super._executor();
  }
}