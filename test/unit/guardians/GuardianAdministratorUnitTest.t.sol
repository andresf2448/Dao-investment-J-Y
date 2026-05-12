// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GuardianAdministrator} from "../../../contracts/guardians/GuardianAdministrator.sol";
import {GuardianBondEscrow} from "../../../contracts/guardians/GuardianBondEscrow.sol";
import {IGuardianBondEscrow} from "../../../contracts/interfaces/guardians/IGuardianBondEscrow.sol";
import {MockGovernorForGuardians} from "../../mocks/MockGovernorForGuardians.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {CommonErrors} from "../../../contracts/libraries/errors/CommonErrors.sol";

contract GuardianAdministratorUnitTest is Test {
  GuardianAdministrator internal administrator;
  GuardianBondEscrow internal escrow;
  MockGovernorForGuardians internal governor;
  MockERC20 internal bondToken;

  address internal guardian = makeAddr("guardian");
  address internal treasury = makeAddr("treasury");

  uint256 internal constant MIN_STAKE = 100e18;

  function setUp() public {
    governor = new MockGovernorForGuardians();
    administrator = new GuardianAdministrator(IGovernor(address(governor)), address(this), MIN_STAKE);

    bondToken = new MockERC20("Bond", "BOND", 18);
    escrow = new GuardianBondEscrow(bondToken, treasury, address(this), address(administrator));

    administrator.setBondEscrow(escrow);

    bondToken.mint(guardian, 1_000e18);
    vm.prank(guardian);
    bondToken.approve(address(escrow), type(uint256).max);
  }

  function testApplyGuardianRevertsWhenEscrowNotSet() public {
    // Test: applyGuardian debe revertir si no hay bondEscrow configurado.
    GuardianAdministrator adminWithoutEscrow =
      new GuardianAdministrator(IGovernor(address(governor)), address(this), MIN_STAKE);

    vm.prank(guardian);
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    adminWithoutEscrow.applyGuardian();
  }

  function testApplyGuardianLocksStakeAndCreatesProposal() public {
    // Test: applyGuardian debe dejar al guardian en Pending, bloquear stake y crear proposal.
    vm.prank(guardian);
    administrator.applyGuardian();

    GuardianAdministrator.GuardianDetail memory detail = administrator.getGuardianDetail(guardian);
    assertEq(uint256(detail.status), uint256(GuardianAdministrator.Status.Pending));
    assertEq(detail.balance, MIN_STAKE);
    assertGt(detail.proposalId, 0);
    assertEq(escrow.getApplicationTokenBalance(), MIN_STAKE);
  }

  function testResolveRejectedApplicationRefundsStake() public {
    // Test: resolveRejectedApplication debe refund cuando la proposal está derrotada/cancelada/expirada.
    vm.prank(guardian);
    administrator.applyGuardian();

    GuardianAdministrator.GuardianDetail memory detailBefore = administrator.getGuardianDetail(guardian);
    governor.setProposalState(detailBefore.proposalId, IGovernor.ProposalState.Defeated);

    uint256 beforeGuardian = bondToken.balanceOf(guardian);
    administrator.resolveRejectedApplication(guardian);

    GuardianAdministrator.GuardianDetail memory detailAfter = administrator.getGuardianDetail(guardian);
    assertEq(uint256(detailAfter.status), uint256(GuardianAdministrator.Status.Rejected));
    assertEq(detailAfter.balance, 0);
    assertEq(bondToken.balanceOf(guardian), beforeGuardian + MIN_STAKE);
  }

  function testGuardianApproveOnlyTimelockAndPendingStatus() public {
    // Test: guardianApprove solo puede ejecutarlo timelock y requiere estado Pending.
    vm.prank(guardian);
    administrator.applyGuardian();

    vm.prank(guardian);
    vm.expectRevert(CommonErrors.Unauthorized.selector);
    administrator.guardianApprove(guardian);

    administrator.guardianApprove(guardian);
    assertTrue(administrator.isActiveGuardian(guardian));
  }

  function testActiveGuardianCanResignAndRecoverStake() public {
    // Test: un guardian activo puede renunciar y recuperar su stake.
    vm.prank(guardian);
    administrator.applyGuardian();
    administrator.guardianApprove(guardian);

    uint256 beforeGuardian = bondToken.balanceOf(guardian);

    vm.prank(guardian);
    administrator.resignGuardian();

    GuardianAdministrator.GuardianDetail memory detailAfter = administrator.getGuardianDetail(guardian);
    assertEq(uint256(detailAfter.status), uint256(GuardianAdministrator.Status.Resigned));
    assertEq(detailAfter.balance, 0);
    assertFalse(administrator.isActiveGuardian(guardian));
    assertEq(bondToken.balanceOf(guardian), beforeGuardian + MIN_STAKE);
  }

  function testTimelockCanBanAndSlashActiveGuardian() public {
    // Test: timelock puede banear guardian activo y slashear su stake al treasury.
    vm.prank(guardian);
    administrator.applyGuardian();
    administrator.guardianApprove(guardian);

    administrator.banGuardian(guardian);

    GuardianAdministrator.GuardianDetail memory detailAfter = administrator.getGuardianDetail(guardian);
    assertEq(uint256(detailAfter.status), uint256(GuardianAdministrator.Status.Banned));
    assertEq(detailAfter.balance, 0);
    assertEq(bondToken.balanceOf(treasury), MIN_STAKE);
    assertFalse(administrator.isActiveGuardian(guardian));
  }

  function testCannotReapplyWhenAlreadyPending() public {
    // Test: un guardian no puede reaplicar mientras está Pending.
    vm.prank(guardian);
    administrator.applyGuardian();

    vm.prank(guardian);
    vm.expectRevert(GuardianAdministrator.GuardianAdministrator__AlreadyApplied.selector);
    administrator.applyGuardian();
  }

  function testResolveRejectedApplicationRevertsWhileProposalStillActive() public {
    // Test: resolveRejectedApplication revierte si proposal sigue activa/no terminal.
    vm.prank(guardian);
    administrator.applyGuardian();

    vm.expectRevert(GuardianAdministrator.GuardianAdministrator__ProposalStillActive.selector);
    administrator.resolveRejectedApplication(guardian);
  }

  function testGettersAndLifecycleValidationReverts() public {
    // Test: getters y lifecycle deben revertir en estados inválidos.
    vm.expectRevert(GuardianAdministrator.GuardianAdministrator__NotGuardianExists.selector);
    administrator.getGuardianDetail(guardian);

    vm.expectRevert(GuardianAdministrator.GuardianAdministrator__NoPendingApplication.selector);
    administrator.getProposalState(guardian);

    vm.prank(guardian);
    vm.expectRevert(GuardianAdministrator.GuardianAdministrator__InvalidStatus.selector);
    administrator.resignGuardian();

    vm.expectRevert(GuardianAdministrator.GuardianAdministrator__InvalidStatus.selector);
    administrator.banGuardian(guardian);
  }

  function testTimelockSettersValidateInputAndAuthorization() public {
    // Test: setBondEscrow y setMinStake son onlyTimelock y validan parámetros.
    vm.prank(guardian);
    vm.expectRevert(CommonErrors.Unauthorized.selector);
    administrator.setMinStake(10);

    vm.expectRevert(CommonErrors.ZeroAmount.selector);
    administrator.setMinStake(0);

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    administrator.setBondEscrow(IGuardianBondEscrow(address(0)));
  }
}
