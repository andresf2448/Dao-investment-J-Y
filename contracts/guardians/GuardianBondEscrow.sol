// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                           IMPORTS
// =============================================================
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IGuardianBondEscrow} from "../interfaces/guardians/IGuardianBondEscrow.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title GuardianBondEscrow
/// @notice Holds and manages guardian application bonds during lifecycle events.
/// @dev Only the configured guardian administrator role can lock, refund, release, or slash bonds.
contract GuardianBondEscrow is IGuardianBondEscrow, AccessControl {

  /*//////////////////////////////////////////////////////////////
                              TYPE DECLARATIONS
  //////////////////////////////////////////////////////////////*/
  using SafeERC20 for IERC20;

  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @notice Role allowed to manage guardian bond lifecycle operations.
  bytes32 public constant GUARDIAN_ADMINISTRATOR_ROLE = keccak256("GUARDIAN_ADMINISTRATOR_ROLE");

  /// @notice ERC20 token used as guardian application bond.
  IERC20 public immutable guardianApplicationToken;

  /// @notice Treasury receiving slashed bond amounts.
  address public immutable treasury;

  /// @notice Current guardian administrator contract address.
  address public guardianAdministrator;

  /// @dev Bond balance tracked per guardian.
  mapping(address => uint256) private _bonded;

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when guardian administrator is updated.
  event GuardianAdministratorSet(address indexed oldGuardianAdministrator, address indexed newGuardianAdministrator);

  /// @notice Emitted when bond is locked for a guardian.
  event BondLocked(address indexed guardian, uint256 amount);

  /// @notice Emitted when bond is refunded.
  event BondRefunded(address indexed guardian, uint256 amount);

  /// @notice Emitted when bond is released on guardian resignation.
  event BondReleasedOnResign(address indexed guardian, uint256 amount);

  /// @notice Emitted when bond is slashed to treasury.
  event BondSlashedToTreasury(address indexed guardian, uint256 amount, address indexed treasury);

  /*//////////////////////////////////////////////////////////////
                                  ERRORS
  //////////////////////////////////////////////////////////////*/
  /// @notice Thrown when requested bond movement exceeds bonded amount.
  error GuardianBondEscrow__InsufficientBond();

  /// @notice Thrown when setting same guardian administrator again.
  error GuardianBondEscrow__SameGuardianAdministrator();

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /// @notice Initializes bond escrow dependencies and roles.
  /// @param guardianApplicationToken_ ERC20 token used as guardian bond.
  /// @param treasury_ Treasury receiving slashed bonds.
  /// @param adminTimelock Timelock receiving default admin role.
  /// @param guardianAdministrator_ Initial guardian administrator with escrow role.
  constructor(
    IERC20 guardianApplicationToken_,
    address treasury_,
    address adminTimelock,
    address guardianAdministrator_
  ) {
    if (address(guardianApplicationToken_) == address(0)) {
      revert CommonErrors.ZeroAddress();
    }
    if (treasury_ == address(0)) {
      revert CommonErrors.ZeroAddress();
    }
    if (adminTimelock == address(0)) {
      revert CommonErrors.ZeroAddress();
    }
    if (guardianAdministrator_ == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    guardianApplicationToken = guardianApplicationToken_;
    treasury = treasury_;
    guardianAdministrator = guardianAdministrator_;

    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock);
    _grantRole(GUARDIAN_ADMINISTRATOR_ROLE, guardianAdministrator_);
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @notice Updates the guardian administrator with escrow permissions.
  /// @param newGuardianAdministrator_ New guardian administrator address.
  function setGuardianAdministrator(address newGuardianAdministrator_) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (newGuardianAdministrator_ == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    address oldGuardianAdministrator = guardianAdministrator;

    if (newGuardianAdministrator_ == oldGuardianAdministrator) {
      revert GuardianBondEscrow__SameGuardianAdministrator();
    }

    _revokeRole(GUARDIAN_ADMINISTRATOR_ROLE, oldGuardianAdministrator);
    _grantRole(GUARDIAN_ADMINISTRATOR_ROLE, newGuardianAdministrator_);

    guardianAdministrator = newGuardianAdministrator_;

    emit GuardianAdministratorSet(oldGuardianAdministrator, newGuardianAdministrator_);
  }

  /// @inheritdoc IGuardianBondEscrow
  function lock(address guardian, uint256 amount) external onlyRole(GUARDIAN_ADMINISTRATOR_ROLE) {
    if (guardian == address(0)) revert CommonErrors.ZeroAddress();
    if (amount == 0) revert CommonErrors.ZeroAmount();

    _bonded[guardian] += amount;
    guardianApplicationToken.safeTransferFrom(guardian, address(this), amount);

    emit BondLocked(guardian, amount);
  }

  /// @inheritdoc IGuardianBondEscrow
  function refund(address guardian, uint256 amount) external onlyRole(GUARDIAN_ADMINISTRATOR_ROLE) {
    if (guardian == address(0)) revert CommonErrors.ZeroAddress();
    if (amount == 0) revert CommonErrors.ZeroAmount();

    uint256 currentBond = _bonded[guardian];
    if (currentBond < amount) revert GuardianBondEscrow__InsufficientBond();

    _bonded[guardian] = currentBond - amount;
    guardianApplicationToken.safeTransfer(guardian, amount);

    emit BondRefunded(guardian, amount);
  }

  /// @inheritdoc IGuardianBondEscrow
  function releaseOnResign(address guardian, uint256 amount) external onlyRole(GUARDIAN_ADMINISTRATOR_ROLE) {
    if (guardian == address(0)) revert CommonErrors.ZeroAddress();
    if (amount == 0) revert CommonErrors.ZeroAmount();

    uint256 currentBond = _bonded[guardian];
    if (currentBond < amount) revert GuardianBondEscrow__InsufficientBond();

    _bonded[guardian] = currentBond - amount;
    guardianApplicationToken.safeTransfer(guardian, amount);

    emit BondReleasedOnResign(guardian, amount);
  }

  /// @inheritdoc IGuardianBondEscrow
  function slashToTreasury(address guardian, uint256 amount) external onlyRole(GUARDIAN_ADMINISTRATOR_ROLE) {
    if (guardian == address(0)) revert CommonErrors.ZeroAddress();
    if (amount == 0) revert CommonErrors.ZeroAmount();

    uint256 currentBond = _bonded[guardian];
    if (currentBond < amount) revert GuardianBondEscrow__InsufficientBond();

    _bonded[guardian] = currentBond - amount;
    guardianApplicationToken.safeTransfer(treasury, amount);

    emit BondSlashedToTreasury(guardian, amount, treasury);
  }

  /// @notice Returns total escrowed token balance held by this contract.
  /// @return Token balance of this escrow contract.
  function getApplicationTokenBalance() external view returns (uint256) {
    return guardianApplicationToken.balanceOf(address(this));
  }
}
