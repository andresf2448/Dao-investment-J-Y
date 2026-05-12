// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {GuardianBondEscrow} from "../../../contracts/guardians/GuardianBondEscrow.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {CommonErrors} from "../../../contracts/libraries/errors/CommonErrors.sol";

contract GuardianBondEscrowUnitTest is Test {
  GuardianBondEscrow internal escrow;
  MockERC20 internal bondToken;

  address internal timelockAdmin = makeAddr("timelockAdmin");
  address internal guardianAdministrator = makeAddr("guardianAdministrator");
  address internal newGuardianAdministrator = makeAddr("newGuardianAdministrator");
  address internal treasury = makeAddr("treasury");
  address internal guardian = makeAddr("guardian");

  function setUp() public {
    bondToken = new MockERC20("Bond", "BOND", 18);
    escrow = new GuardianBondEscrow(bondToken, treasury, timelockAdmin, guardianAdministrator);

    bondToken.mint(guardian, 1_000e18);
    vm.prank(guardian);
    bondToken.approve(address(escrow), type(uint256).max);
  }

  function testOnlyGuardianAdministratorCanLockRefundReleaseAndSlash() public {
    // Test: lock/refund/release/slash solo pueden ser llamados por GUARDIAN_ADMINISTRATOR_ROLE.
    vm.expectRevert();
    escrow.lock(guardian, 1e18);

    vm.prank(guardianAdministrator);
    escrow.lock(guardian, 100e18);

    vm.expectRevert();
    escrow.refund(guardian, 10e18);

    vm.prank(guardianAdministrator);
    escrow.refund(guardian, 10e18);

    vm.prank(guardianAdministrator);
    escrow.lock(guardian, 10e18);

    vm.expectRevert();
    escrow.releaseOnResign(guardian, 1e18);

    vm.prank(guardianAdministrator);
    escrow.releaseOnResign(guardian, 1e18);

    vm.prank(guardianAdministrator);
    escrow.lock(guardian, 5e18);

    vm.expectRevert();
    escrow.slashToTreasury(guardian, 1e18);

    vm.prank(guardianAdministrator);
    escrow.slashToTreasury(guardian, 1e18);
  }

  function testLockTransfersBondToEscrow() public {
    // Test: lock transfiere tokens desde guardian al escrow y aumenta su bond.
    uint256 beforeGuardian = bondToken.balanceOf(guardian);

    vm.prank(guardianAdministrator);
    escrow.lock(guardian, 200e18);

    assertEq(bondToken.balanceOf(guardian), beforeGuardian - 200e18);
    assertEq(escrow.getApplicationTokenBalance(), 200e18);
  }

  function testRefundReturnsBondToGuardian() public {
    // Test: refund devuelve bond al guardian y reduce el saldo escrow.
    vm.prank(guardianAdministrator);
    escrow.lock(guardian, 150e18);

    uint256 beforeGuardian = bondToken.balanceOf(guardian);

    vm.prank(guardianAdministrator);
    escrow.refund(guardian, 40e18);

    assertEq(bondToken.balanceOf(guardian), beforeGuardian + 40e18);
    assertEq(escrow.getApplicationTokenBalance(), 110e18);
  }

  function testReleaseOnResignReturnsBondToGuardian() public {
    // Test: releaseOnResign devuelve bond al guardian cuando renuncia.
    vm.prank(guardianAdministrator);
    escrow.lock(guardian, 90e18);

    uint256 beforeGuardian = bondToken.balanceOf(guardian);

    vm.prank(guardianAdministrator);
    escrow.releaseOnResign(guardian, 25e18);

    assertEq(bondToken.balanceOf(guardian), beforeGuardian + 25e18);
    assertEq(escrow.getApplicationTokenBalance(), 65e18);
  }

  function testSlashToTreasurySendsFundsToTreasury() public {
    // Test: slashToTreasury envía los fondos slasheados al treasury.
    vm.prank(guardianAdministrator);
    escrow.lock(guardian, 80e18);

    vm.prank(guardianAdministrator);
    escrow.slashToTreasury(guardian, 30e18);

    assertEq(bondToken.balanceOf(treasury), 30e18);
    assertEq(escrow.getApplicationTokenBalance(), 50e18);
  }

  function testCannotWithdrawMoreThanBondedAmount() public {
    // Test: no se puede refund/release/slash por encima del bond bloqueado.
    vm.prank(guardianAdministrator);
    escrow.lock(guardian, 10e18);

    vm.prank(guardianAdministrator);
    vm.expectRevert(GuardianBondEscrow.GuardianBondEscrow__InsufficientBond.selector);
    escrow.refund(guardian, 11e18);

    vm.prank(guardianAdministrator);
    vm.expectRevert(GuardianBondEscrow.GuardianBondEscrow__InsufficientBond.selector);
    escrow.releaseOnResign(guardian, 11e18);

    vm.prank(guardianAdministrator);
    vm.expectRevert(GuardianBondEscrow.GuardianBondEscrow__InsufficientBond.selector);
    escrow.slashToTreasury(guardian, 11e18);
  }

  function testSetGuardianAdministratorRotatesRoles() public {
    // Test: cambiar guardian administrator revoca rol anterior y otorga el nuevo.
    vm.prank(timelockAdmin);
    escrow.setGuardianAdministrator(newGuardianAdministrator);

    vm.prank(guardianAdministrator);
    vm.expectRevert();
    escrow.lock(guardian, 1e18);

    vm.prank(newGuardianAdministrator);
    escrow.lock(guardian, 1e18);
  }

  function testSetGuardianAdministratorRejectsZeroAndSame() public {
    // Test: setGuardianAdministrator revierte con zero address o mismo admin actual.
    vm.prank(timelockAdmin);
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    escrow.setGuardianAdministrator(address(0));

    vm.prank(timelockAdmin);
    vm.expectRevert(GuardianBondEscrow.GuardianBondEscrow__SameGuardianAdministrator.selector);
    escrow.setGuardianAdministrator(guardianAdministrator);
  }

  function testLockRejectsZeroAddressAndZeroAmount() public {
    // Test: lock revierte si guardian es cero o amount es cero.
    vm.prank(guardianAdministrator);
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    escrow.lock(address(0), 1e18);

    vm.prank(guardianAdministrator);
    vm.expectRevert(CommonErrors.ZeroAmount.selector);
    escrow.lock(guardian, 0);
  }
}
