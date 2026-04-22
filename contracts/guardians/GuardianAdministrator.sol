// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IGuardianBondEscrow} from "../interfaces/guardians/IGuardianBondEscrow.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";

contract GuardianAdministrator {
  using EnumerableSet for EnumerableSet.AddressSet;
  using Strings for address;
  using Strings for uint256;

  enum Status {
    Inactive,
    Pending,
    Active,
    Rejected,
    Resigned,
    Banned
  }

  struct GuardianDetail {
    Status status;
    uint256 balance;
    uint256 blockRequest;
    uint256 proposalId;
  }

  uint256 public minStake;
  IGovernor public immutable governor;
  IGuardianBondEscrow public bondEscrow;
  address public immutable timelock;

  mapping(address => GuardianDetail) private guardians;
  EnumerableSet.AddressSet private activeGuardians;

  event GuardianApplied(address indexed guardian, uint256 indexed proposalId);
  event GuardianApproved(address indexed guardian);
  event GuardianRejected(address indexed guardian, uint256 stakeRefunded);
  event GuardianResigned(address indexed guardian, uint256 stakeRefunded);
  event GuardianBanned(address indexed guardian, uint256 stakeForfeit);
  event MinStakeUpdated(uint256 oldStake, uint256 newStake);
  event GovernanceVotesDelegated(address indexed governanceToken, address indexed delegatee);

  error GuardianAdministrator__AlreadyApplied();
  error GuardianAdministrator__InvalidStatus();
  error GuardianAdministrator__NoPendingApplication();
  error GuardianAdministrator__ProposalStillActive();
  error GuardianAdministrator__NotGuardianExists();

  modifier onlyTimelock() {
    if(msg.sender != timelock) {
      revert CommonErrors.Unauthorized();
    }
    _;
  }

  constructor(
    IGovernor governor_,
    address timelock_,
    uint256 minStake_
  ) {
    if (address(governor_) == address(0))
      revert CommonErrors.ZeroAddress();

    if (timelock_ == address(0))
      revert CommonErrors.ZeroAddress();

    if (minStake_ == 0)
      revert CommonErrors.ZeroAmount();

    governor = governor_;
    timelock = timelock_;
    minStake = minStake_;
  }

  function setBondEscrow(IGuardianBondEscrow bondEscrow_) external onlyTimelock {
    if (address(bondEscrow_) == address(0))
      revert CommonErrors.ZeroAddress();
    bondEscrow = bondEscrow_;
  }

  function selfDelegateGovernanceVotes(address governanceToken_) external {
    if (governanceToken_ == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    IVotes(governanceToken_).delegate(address(this));

    emit GovernanceVotesDelegated(governanceToken_, address(this));
  }

  function applyGuardian() external {
    if(address(bondEscrow) == address(0))
      revert CommonErrors.ZeroAddress();

    address sender = msg.sender;
    GuardianDetail storage guardian = guardians[sender];

    if (guardian.status != Status.Inactive)
      revert GuardianAdministrator__AlreadyApplied();

    guardian.status = Status.Pending;
    guardian.balance = minStake;
    guardian.blockRequest = block.number;

    bondEscrow.lock(sender, minStake);

    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);

    targets[0] = address(this);
    values[0] = 0;
    calldatas[0] = abi.encodeCall(this.guardianApprove, (sender));

    string memory description = string.concat(
      "Guardian application: ",
      sender.toHexString(),
      " block: ",
      block.number.toString()
    );

    uint256 proposalId = governor.propose(
      targets,
      values,
      calldatas,
      description
    );

    guardian.proposalId = proposalId;

    emit GuardianApplied(sender, proposalId);
  }

  function guardianApprove(address guardian) external onlyTimelock {
    if (guardian == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    GuardianDetail storage guardianDetail = guardians[guardian];

    if (guardianDetail.status != Status.Pending) {
      revert GuardianAdministrator__InvalidStatus();
    }

    guardianDetail.status = Status.Active;
    activeGuardians.add(guardian);

    emit GuardianApproved(guardian);
  }

  function resolveRejectedApplication(address guardian) external {
    GuardianDetail storage guardianDetail = guardians[guardian];

    if (guardianDetail.status != Status.Pending) {
      revert GuardianAdministrator__NoPendingApplication();
    }

    IGovernor.ProposalState state = governor.state(
      guardianDetail.proposalId
    );

    if (
      state != IGovernor.ProposalState.Defeated &&
      state != IGovernor.ProposalState.Canceled &&
      state != IGovernor.ProposalState.Expired
    ) {
      revert GuardianAdministrator__ProposalStillActive();
    }

    uint256 refund = guardianDetail.balance;

    guardianDetail.status = Status.Rejected;
    guardianDetail.balance = 0;

    if (refund > 0) {
      bondEscrow.refund(guardian, refund);
    }

    emit GuardianRejected(guardian, refund);
  }

  function resignGuardian() external {
    address sender = msg.sender;
    GuardianDetail storage guardian = guardians[sender];

    if (guardian.status != Status.Active) {
      revert GuardianAdministrator__InvalidStatus();
    }

    uint256 refund = guardian.balance;

    guardian.status = Status.Resigned;
    guardian.balance = 0;
    activeGuardians.remove(sender);

    if (refund > 0) {
      bondEscrow.releaseOnResign(sender, refund);
    }

    emit GuardianResigned(sender, refund);
  }

  function banGuardian(address guardian) external onlyTimelock {
    if (guardian == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    GuardianDetail storage guardianDetail = guardians[guardian];

    if (guardianDetail.status != Status.Active) {
      revert GuardianAdministrator__InvalidStatus();
    }

    uint256 forfeit = guardianDetail.balance;

    guardianDetail.status = Status.Banned;
    guardianDetail.balance = 0;
    activeGuardians.remove(guardian);

    if (forfeit > 0) {
      bondEscrow.slashToTreasury(guardian, forfeit);
    }

    emit GuardianBanned(guardian, forfeit);
  }

  function setMinStake(uint256 newMinStake) external onlyTimelock {
    if (newMinStake == 0) {
      revert CommonErrors.ZeroAmount();
    }

    uint256 oldStake = minStake;
    minStake = newMinStake;

    emit MinStakeUpdated(oldStake, newMinStake);
  }

  function getGuardianDetail(address guardian)
    external
    view
    returns (GuardianDetail memory)
  {
    GuardianDetail storage guardianDetail = guardians[guardian];

    if (guardianDetail.status == Status.Inactive) {
      revert GuardianAdministrator__NotGuardianExists();
    }

    return guardianDetail;
  }

  function getProposalState(address guardian)
    external
    view
    returns (IGovernor.ProposalState)
  {
    GuardianDetail storage guardianDetail = guardians[guardian];

    if (guardianDetail.status != Status.Pending) {
      revert GuardianAdministrator__NoPendingApplication();
    }

    return governor.state(guardianDetail.proposalId);
  }

  function isActiveGuardian(address guardian)
    external
    view
    returns (bool)
  {
    return guardians[guardian].status == Status.Active;
  }

  function totalActiveGuardians() external view returns (uint256) {
    return activeGuardians.length();
  }
}
