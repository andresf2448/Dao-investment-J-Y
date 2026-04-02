// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract GuardianAdministrator{
  using SafeERC20 for IERC20;
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
  IERC20 public immutable bondingToken;
  IGovernor public immutable governor;
  address public immutable timelock;
  address public immutable treasury;

  mapping(address => GuardianDetail) private guardians;

  event GuardianApplied(address indexed guardian, uint256 indexed proposalId);
  event GuardianApproved(address indexed guardian);
  event GuardianRejected(address indexed guardian, uint256 stakeRefunded);
  event GuardianResigned(address indexed guardian, uint256 stakeRefunded);
  event GuardianBanned(address indexed guardian, uint256 stakeForfeit);
  event MinStakeUpdated(uint256 oldStake, uint256 newStake);

  error GuardianAdministrator__InsufficientBalance();
  error GuardianAdministrator__AlreadyApplied();
  error GuardianAdministrator__InvalidAddress();
  error GuardianAdministrator__InvalidStatus();
  error GuardianAdministrator__NoPendingApplication();
  error GuardianAdministrator__ProposalStillActive();
  error GuardianAdministrator__NotAuthorized();
  error GuardianAdministrator__InvalidStakeAmount();

  modifier onlyTimelock() {
    if(msg.sender != timelock) revert GuardianAdministrator__NotAuthorized();
    _;
  }

  constructor(
    IERC20 bondingToken_,
    IGovernor governor_,
    address timelock_,
    address treasury_,
    uint256 minStake_
  ) {
    if(address(bondingToken_) == address(0)) revert GuardianAdministrator__InvalidAddress();
    if(address(governor_) == address(0)) revert GuardianAdministrator__InvalidAddress();
    if (timelock_ == address(0)) revert GuardianAdministrator__InvalidAddress();
    if (treasury_ == address(0)) revert GuardianAdministrator__InvalidAddress();
    if (minStake_ == 0) revert GuardianAdministrator__InvalidStakeAmount();

    bondingToken = bondingToken_;
    governor = governor_;
    timelock = timelock_;
    treasury = treasury_;
    minStake = minStake_;
  }

  function applyGuardian() external {
    address sender = msg.sender;
    GuardianDetail storage guardian = guardians[sender];

    if(guardian.status != Status.Inactive)
      revert GuardianAdministrator__AlreadyApplied();

    guardian.status = Status.Pending;
    guardian.balance = minStake;
    guardian.blockRequest = block.number;
    guardian.proposalId = 0;

    bondingToken.safeTransferFrom(sender, address(this), minStake);

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
    GuardianDetail storage guardianDetail = guardians[guardian];

    if(guardian == address(0))
      revert GuardianAdministrator__InvalidAddress();
    if(guardianDetail.status != Status.Pending)
      revert GuardianAdministrator__InvalidStatus();

    guardianDetail.status = Status.Active;

    emit GuardianApproved(guardian);
  }

  function resolveRejectedApplication(address guardian) external {
    GuardianDetail storage guardianDetail = guardians[guardian];

    if(guardianDetail.status != Status.Pending)
      revert GuardianAdministrator__NoPendingApplication();
    
    IGovernor.ProposalState state = governor.state(
      guardianDetail.proposalId
    );

    if (
    state != IGovernor.ProposalState.Defeated &&
    state != IGovernor.ProposalState.Canceled &&
    state != IGovernor.ProposalState.Expired
    ) revert GuardianAdministrator__ProposalStillActive();

    uint256 refund = guardianDetail.balance;
    guardianDetail.status  = Status.Rejected;
    guardianDetail.balance = 0;

    bondingToken.safeTransfer(guardian, refund);

    emit GuardianRejected(guardian, refund);
  }

  function resignGuardian() external {
    address sender = msg.sender;
    GuardianDetail storage guardian = guardians[sender];

    if(guardian.status != Status.Active)
      revert GuardianAdministrator__InvalidStatus();
    
    uint256 refund = guardian.balance;
    guardian.status = Status.Resigned;
    guardian.balance = 0;

    bondingToken.safeTransfer(sender, refund);
    emit GuardianResigned(sender, refund);
  }

  function banGuardian(address guardian) external onlyTimelock {
    GuardianDetail storage guardianDetail = guardians[guardian];

    if(guardian == address(0))
      revert GuardianAdministrator__InvalidAddress();
    if(guardianDetail.status != Status.Active)
      revert GuardianAdministrator__InvalidStatus();

    uint256 forfeit = guardianDetail.balance;
    guardianDetail.status = Status.Banned;
    guardianDetail.balance = 0;

    if(forfeit > 0) {
      bondingToken.safeTransfer(treasury, forfeit);
    }

    emit GuardianBanned(guardian, forfeit);
  }

  function setMinStake(uint256 newMinStake) external onlyTimelock {
    if(newMinStake == 0) revert GuardianAdministrator__InvalidStakeAmount();

    uint256 old = minStake;
    minStake = newMinStake;

    emit MinStakeUpdated(old, newMinStake);
  }

  function getGuardianDetail(address guardian)
    external
    view
    returns(GuardianDetail memory)
  {
    GuardianDetail storage guardianDetail =  guardians[guardian];

    if(guardianDetail.status == Status.Inactive)
      revert GuardianAdministrator__InvalidAddress();

    return guardianDetail;
  }

  function getProposalState(address guardian)
    external
    view
    returns(IGovernor.ProposalState)
  {
    GuardianDetail storage guardianDetail =  guardians[guardian];

    if(guardianDetail.status != Status.Pending)
      revert GuardianAdministrator__NoPendingApplication();

    return governor.state(guardianDetail.proposalId);
  }

  function isActiveGuardian(address guardian)
    external
    view
    returns(bool)
  {
    return guardians[guardian].status == Status.Active;
  }
}