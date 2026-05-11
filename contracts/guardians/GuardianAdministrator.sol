// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// =============================================================
//                           IMPORTS
// =============================================================
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IGuardianBondEscrow} from "../interfaces/guardians/IGuardianBondEscrow.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title GuardianAdministrator
/// @notice Manages guardian onboarding, approval, resignation, and ban lifecycle.
/// @dev Guardian approval is delegated to governance via proposal + timelock execution.
contract GuardianAdministrator is ReentrancyGuardTransient{
  using EnumerableSet for EnumerableSet.AddressSet;
  using Strings for address;
  using Strings for uint256;

  /*//////////////////////////////////////////////////////////////
                              TYPE DECLARATIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Lifecycle status of a guardian account.
  enum Status {
    Inactive,
    Pending,
    Active,
    Rejected,
    Resigned,
    Banned
  }

  /// @notice Stores guardian lifecycle and stake metadata.
  struct GuardianDetail {
    /// @notice Current guardian status.
    Status status;
    /// @notice Bond amount currently associated with guardian position.
    uint256 balance;
    /// @notice Block where the application was submitted.
    uint256 blockRequest;
    /// @notice Governance proposal id linked to application approval.
    uint256 proposalId;
  }

  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @notice Minimum bond stake required to apply as guardian.
  uint256 public minStake;

  /// @notice Governor used to create and track guardian approval proposals.
  IGovernor public immutable governor;

  /// @notice Escrow that locks/refunds/slashes guardian bonds.
  IGuardianBondEscrow public bondEscrow;

  /// @notice Timelock authorized to execute privileged guardian lifecycle actions.
  address public immutable timelock;

  /// @dev Storage of guardian details by guardian address.
  mapping(address => GuardianDetail) private guardians;

  /// @dev Set of currently active guardians.
  EnumerableSet.AddressSet private activeGuardians;

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when bond escrow is updated.
  event BondEscrowSet(IGuardianBondEscrow bondEscrow);

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when a guardian application proposal is created.
  event GuardianApplied(address indexed guardian, uint256 indexed proposalId);

  /// @notice Emitted when a pending guardian is approved and activated.
  event GuardianApproved(address indexed guardian);

  /// @notice Emitted when a pending application is rejected and stake refunded.
  event GuardianRejected(address indexed guardian, uint256 stakeRefunded);

  /// @notice Emitted when an active guardian resigns and stake is released.
  event GuardianResigned(address indexed guardian, uint256 stakeRefunded);

  /// @notice Emitted when a guardian is banned and stake is slashed.
  event GuardianBanned(address indexed guardian, uint256 stakeForfeit);

  /// @notice Emitted when minimum stake requirement changes.
  event MinStakeUpdated(uint256 oldStake, uint256 newStake);

  /// @notice Emitted when this contract delegates its governance voting power.
  event GovernanceVotesDelegated(address indexed governanceToken, address indexed delegatee);

  /*//////////////////////////////////////////////////////////////
                                  ERRORS
  //////////////////////////////////////////////////////////////*/
  /// @notice Thrown when a non-inactive guardian attempts to apply again.
  error GuardianAdministrator__AlreadyApplied();

  /// @notice Thrown when operation is not valid for current guardian status.
  error GuardianAdministrator__InvalidStatus();

  /// @notice Thrown when a pending guardian application is required but missing.
  error GuardianAdministrator__NoPendingApplication();

  /// @notice Thrown when proposal has not reached a reject-like terminal state yet.
  error GuardianAdministrator__ProposalStillActive();

  /// @notice Thrown when requested guardian detail does not exist.
  error GuardianAdministrator__NotGuardianExists();

  /*//////////////////////////////////////////////////////////////
                              MODIFIERS
  //////////////////////////////////////////////////////////////*/
  /// @dev Restricts function access to configured timelock.
  modifier onlyTimelock() {
    if (msg.sender != timelock) {
      revert CommonErrors.Unauthorized();
    }
    _;
  }

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /// @notice Creates the guardian administrator with governance and staking parameters.
  /// @param governor_ Governor contract used to create guardian approval proposals.
  /// @param timelock_ Timelock authorized to execute privileged lifecycle operations.
  /// @param minStake_ Minimum bond required to apply as guardian.
  constructor(IGovernor governor_, address timelock_, uint256 minStake_) {
    if (address(governor_) == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    if (timelock_ == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    if (minStake_ == 0) {
      revert CommonErrors.ZeroAmount();
    }

    governor = governor_;
    timelock = timelock_;
    minStake = minStake_;
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @notice Sets the bond escrow contract used to lock/refund/slash guardian bonds.
  /// @param bondEscrow_ Bond escrow contract.
  function setBondEscrow(IGuardianBondEscrow bondEscrow_) external onlyTimelock {
    if (address(bondEscrow_) == address(0)) {
      revert CommonErrors.ZeroAddress();
    }
    bondEscrow = bondEscrow_;
    emit BondEscrowSet(bondEscrow_);
  }

  /// @notice Delegates governance voting power held by this contract to itself.
  /// @param governanceToken_ Governance token implementing IVotes.
  function selfDelegateGovernanceVotes(address governanceToken_) external {
    if (governanceToken_ == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    IVotes(governanceToken_).delegate(address(this));

    emit GovernanceVotesDelegated(governanceToken_, address(this));
  }

  /// @notice Applies caller as guardian, locks bond, and opens approval proposal.
  function applyGuardian() external nonReentrant {
    if (address(bondEscrow) == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    address sender = msg.sender;
    GuardianDetail storage guardian = guardians[sender];

    if (guardian.status != Status.Inactive) {
      revert GuardianAdministrator__AlreadyApplied();
    }

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

    string memory description =
      string.concat("Guardian application: ", sender.toHexString(), " block: ", block.number.toString());

    uint256 proposalId = governor.propose(targets, values, calldatas, description);

    guardian.proposalId = proposalId;

    emit GuardianApplied(sender, proposalId);
  }

  /// @notice Marks a pending guardian as active after successful governance flow.
  /// @param guardian Guardian address to approve.
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

  /// @notice Resolves rejected/canceled/expired applications and refunds stake.
  /// @param guardian Guardian applicant address.
  function resolveRejectedApplication(address guardian) external nonReentrant {
    GuardianDetail storage guardianDetail = guardians[guardian];

    if (guardianDetail.status != Status.Pending) {
      revert GuardianAdministrator__NoPendingApplication();
    }

    IGovernor.ProposalState state = governor.state(guardianDetail.proposalId);

    if (
      state != IGovernor.ProposalState.Defeated && state != IGovernor.ProposalState.Canceled
        && state != IGovernor.ProposalState.Expired
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

  /// @notice Resigns caller from active guardian role and refunds remaining bond.
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

  /// @notice Bans an active guardian and slashes their bonded stake to treasury.
  /// @param guardian Guardian address to ban.
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

  /// @notice Updates minimum stake required for future guardian applications.
  /// @param newMinStake New minimum stake amount.
  function setMinStake(uint256 newMinStake) external onlyTimelock {
    if (newMinStake == 0) {
      revert CommonErrors.ZeroAmount();
    }

    uint256 oldStake = minStake;
    minStake = newMinStake;

    emit MinStakeUpdated(oldStake, newMinStake);
  }

  /// @notice Returns guardian details for a non-inactive guardian.
  /// @param guardian Guardian address.
  /// @return Guardian lifecycle and bond detail.
  function getGuardianDetail(address guardian) external view returns (GuardianDetail memory) {
    GuardianDetail storage guardianDetail = guardians[guardian];

    if (guardianDetail.status == Status.Inactive) {
      revert GuardianAdministrator__NotGuardianExists();
    }

    return guardianDetail;
  }

  /// @notice Returns proposal state for a pending guardian application.
  /// @param guardian Guardian applicant address.
  /// @return Current governance proposal state.
  function getProposalState(address guardian) external view returns (IGovernor.ProposalState) {
    GuardianDetail storage guardianDetail = guardians[guardian];

    if (guardianDetail.status != Status.Pending) {
      revert GuardianAdministrator__NoPendingApplication();
    }

    return governor.state(guardianDetail.proposalId);
  }

  /// @notice Indicates whether a guardian is currently active.
  /// @param guardian Guardian address.
  /// @return True when guardian status is Active.
  function isActiveGuardian(address guardian) external view returns (bool) {
    return guardians[guardian].status == Status.Active;
  }

  /// @notice Returns total number of active guardians.
  /// @return Number of currently active guardians.
  function totalActiveGuardians() external view returns (uint256) {
    return activeGuardians.length();
  }
}
