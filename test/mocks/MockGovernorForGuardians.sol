// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract MockGovernorForGuardians {
  uint256 private _nextProposalId = 1;
  mapping(uint256 => IGovernor.ProposalState) public proposalState;

  function propose(address[] memory, uint256[] memory, bytes[] memory, string memory) external returns (uint256) {
    uint256 id = _nextProposalId++;
    proposalState[id] = IGovernor.ProposalState.Pending;
    return id;
  }

  function state(uint256 proposalId) external view returns (IGovernor.ProposalState) {
    return proposalState[proposalId];
  }

  function setProposalState(uint256 proposalId, IGovernor.ProposalState state_) external {
    proposalState[proposalId] = state_;
  }
}
