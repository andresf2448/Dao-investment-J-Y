// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IGuardianBondEscrow} from "../interfaces/guardians/IGuardianBondEscrow.sol";

contract GuardianBondEscrow is IGuardianBondEscrow, AccessControl {
  using SafeERC20 for IERC20;

  bytes32 public constant GUARDIAN_ADMINISTRATOR_ROLE = keccak256("GUARDIAN_ADMINISTRATOR_ROLE");

  IERC20 public immutable bondingToken;
  address public immutable treasury;
  address public guardianAdministrator;

  mapping(address => uint256) private _bonded;

  event GuardianAdministratorSet(
    address indexed oldGuardianAdministrator,
    address indexed newGuardianAdministrator
  );
  event BondLocked(address indexed guardian, uint256 amount);
  event BondRefunded(address indexed guardian, uint256 amount);
  event BondReleasedOnResign(address indexed guardian, uint256 amount);
  event BondSlashedToTreasury(
    address indexed guardian,
    uint256 amount,
    address indexed treasury
  );

  error GuardianBondEscrow__ZeroAddress();
  error GuardianBondEscrow__InvalidAmount();
  error GuardianBondEscrow__InsufficientBond();
  error GuardianBondEscrow__SameGuardianAdministrator();

  constructor(
    IERC20 bondingToken_,
    address treasury_,
    address adminProtocol_,
    address guardianAdministrator_
  ) {
    if (address(bondingToken_) == address(0)) {
      revert GuardianBondEscrow__ZeroAddress();
    }
    if (treasury_ == address(0)) {
      revert GuardianBondEscrow__ZeroAddress();
    }
    if (adminProtocol_ == address(0)) {
      revert GuardianBondEscrow__ZeroAddress();
    }
    if (guardianAdministrator_ == address(0)) {
      revert GuardianBondEscrow__ZeroAddress();
    }

    bondingToken = bondingToken_;
    treasury = treasury_;
    guardianAdministrator = guardianAdministrator_;

    _grantRole(DEFAULT_ADMIN_ROLE, adminProtocol_);
    _grantRole(GUARDIAN_ADMINISTRATOR_ROLE, guardianAdministrator_);
  }

  function setGuardianAdministrator(address newGuardianAdministrator_)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    if (newGuardianAdministrator_ == address(0)) {
      revert GuardianBondEscrow__ZeroAddress();
    }

    address oldGuardianAdministrator = guardianAdministrator;

    if (newGuardianAdministrator_ == oldGuardianAdministrator) {
      revert GuardianBondEscrow__SameGuardianAdministrator();
    }

    _revokeRole(GUARDIAN_ADMINISTRATOR_ROLE, oldGuardianAdministrator);
    _grantRole(GUARDIAN_ADMINISTRATOR_ROLE, newGuardianAdministrator_);

    guardianAdministrator = newGuardianAdministrator_;

    emit GuardianAdministratorSet(
      oldGuardianAdministrator,
      newGuardianAdministrator_
    );
  }

  function lock(address guardian, uint256 amount)
    external
    onlyRole(GUARDIAN_ADMINISTRATOR_ROLE)
  {
    if (guardian == address(0)) revert GuardianBondEscrow__ZeroAddress();
    if (amount == 0) revert GuardianBondEscrow__InvalidAmount();

    _bonded[guardian] += amount;
    bondingToken.safeTransferFrom(guardian, address(this), amount);

    emit BondLocked(guardian, amount);
  }

  function refund(address guardian, uint256 amount)
    external
    onlyRole(GUARDIAN_ADMINISTRATOR_ROLE)
  {
    if (guardian == address(0)) revert GuardianBondEscrow__ZeroAddress();
    if (amount == 0) revert GuardianBondEscrow__InvalidAmount();

    uint256 currentBond = _bonded[guardian];
    if (currentBond < amount) revert GuardianBondEscrow__InsufficientBond();

    _bonded[guardian] = currentBond - amount;
    bondingToken.safeTransfer(guardian, amount);

    emit BondRefunded(guardian, amount);
  }

  function releaseOnResign(address guardian, uint256 amount)
    external
    onlyRole(GUARDIAN_ADMINISTRATOR_ROLE)
  {
    if (guardian == address(0)) revert GuardianBondEscrow__ZeroAddress();
    if (amount == 0) revert GuardianBondEscrow__InvalidAmount();

    uint256 currentBond = _bonded[guardian];
    if (currentBond < amount) revert GuardianBondEscrow__InsufficientBond();

    _bonded[guardian] = currentBond - amount;
    bondingToken.safeTransfer(guardian, amount);

    emit BondReleasedOnResign(guardian, amount);
  }

  function slashToTreasury(address guardian, uint256 amount)
    external
    onlyRole(GUARDIAN_ADMINISTRATOR_ROLE)
  {
    if (guardian == address(0)) revert GuardianBondEscrow__ZeroAddress();
    if (amount == 0) revert GuardianBondEscrow__InvalidAmount();

    uint256 currentBond = _bonded[guardian];
    if (currentBond < amount) revert GuardianBondEscrow__InsufficientBond();

    _bonded[guardian] = currentBond - amount;
    bondingToken.safeTransfer(treasury, amount);

    emit BondSlashedToTreasury(guardian, amount, treasury);
  }

  function bondedBalance(address guardian)
    external
    view
    override
    returns (uint256)
  {
    return _bonded[guardian];
  }
}