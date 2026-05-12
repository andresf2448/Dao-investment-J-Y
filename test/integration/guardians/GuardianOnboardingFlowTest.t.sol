// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TimeLock} from "../../../contracts/governance/TimeLock.sol";
import {GovernanceToken} from "../../../contracts/governance/GovernanceToken.sol";
import {DaoGovernor} from "../../../contracts/governance/DaoGovernor.sol";
import {GuardianAdministrator} from "../../../contracts/guardians/GuardianAdministrator.sol";
import {GuardianBondEscrow} from "../../../contracts/guardians/GuardianBondEscrow.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

contract GuardianOnboardingFlowTest is Test {
  using Strings for address;
  using Strings for uint256;

  TimeLock internal timeLock;
  GovernanceToken internal governanceToken;
  DaoGovernor internal governor;
  GuardianAdministrator internal guardianAdministrator;
  GuardianBondEscrow internal escrow;
  MockERC20 internal bondToken;

  address internal guardian = makeAddr("guardian");
  address internal treasury = makeAddr("treasury");

  uint256 internal constant PROPOSAL_THRESHOLD = 100e18;
  uint256 internal constant MIN_STAKE = 50e18;
  uint48 internal constant VOTING_DELAY = 1;
  uint32 internal constant VOTING_PERIOD = 8;

  function setUp() public {
    address[] memory proposers = new address[](0);
    address[] memory executors = new address[](0);
    timeLock = new TimeLock(1 days, proposers, executors, address(this));

    governanceToken = new GovernanceToken(address(this));
    governor = new DaoGovernor(governanceToken, timeLock, PROPOSAL_THRESHOLD, VOTING_DELAY, VOTING_PERIOD);

    timeLock.grantRole(timeLock.PROPOSER_ROLE(), address(governor));
    timeLock.grantRole(timeLock.EXECUTOR_ROLE(), address(governor));
    timeLock.grantRole(timeLock.CANCELLER_ROLE(), address(governor));

    guardianAdministrator = new GuardianAdministrator(governor, address(timeLock), MIN_STAKE);

    bondToken = new MockERC20("Bond", "BOND", 18);
    escrow = new GuardianBondEscrow(bondToken, treasury, address(timeLock), address(guardianAdministrator));

    vm.prank(address(timeLock));
    guardianAdministrator.setBondEscrow(escrow);

    governanceToken.grantRole(governanceToken.MINTER_ROLE(), address(this));
    governanceToken.mint(address(guardianAdministrator), PROPOSAL_THRESHOLD);

    guardianAdministrator.selfDelegateGovernanceVotes(address(governanceToken));

    bondToken.mint(guardian, 1_000e18);
    vm.prank(guardian);
    bondToken.approve(address(escrow), type(uint256).max);

    vm.roll(block.number + 1);
  }

  function testGuardianApplyThenApproveThroughGovernorAndResign() public {
    // Test: guardian aplica, proposal se aprueba por gobernanza y luego puede renunciar recuperando stake.
    vm.prank(guardian);
    guardianAdministrator.applyGuardian();

    GuardianAdministrator.GuardianDetail memory detail = guardianAdministrator.getGuardianDetail(guardian);
    assertEq(uint256(detail.status), uint256(GuardianAdministrator.Status.Pending));
    assertEq(escrow.getApplicationTokenBalance(), MIN_STAKE);

    vm.roll(block.number + VOTING_DELAY + 1);
    vm.prank(address(guardianAdministrator));
    governor.castVote(detail.proposalId, 1);

    vm.roll(block.number + VOTING_PERIOD + 1);

    address[] memory targets = new address[](1);
    targets[0] = address(guardianAdministrator);

    uint256[] memory values = new uint256[](1);
    values[0] = 0;

    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeCall(guardianAdministrator.guardianApprove, (guardian));

    string memory description =
      string.concat("Guardian application: ", guardian.toHexString(), " block: ", detail.blockRequest.toString());
    bytes32 descriptionHash = keccak256(bytes(description));

    governor.queue(targets, values, calldatas, descriptionHash);

    vm.warp(block.timestamp + timeLock.getMinDelay() + 1);
    vm.roll(block.number + 1);

    governor.execute(targets, values, calldatas, descriptionHash);

    assertTrue(guardianAdministrator.isActiveGuardian(guardian));

    uint256 beforeResignBalance = bondToken.balanceOf(guardian);

    vm.prank(guardian);
    guardianAdministrator.resignGuardian();

    assertFalse(guardianAdministrator.isActiveGuardian(guardian));
    assertEq(bondToken.balanceOf(guardian), beforeResignBalance + MIN_STAKE);
  }

  function testTimelockCanBanAnActiveGuardianAndSlashStake() public {
    // Test: luego de aprobación, timelock puede banear guardian y enviar stake al treasury.
    vm.prank(guardian);
    guardianAdministrator.applyGuardian();

    GuardianAdministrator.GuardianDetail memory detail = guardianAdministrator.getGuardianDetail(guardian);

    vm.roll(block.number + VOTING_DELAY + 1);
    vm.prank(address(guardianAdministrator));
    governor.castVote(detail.proposalId, 1);
    vm.roll(block.number + VOTING_PERIOD + 1);

    address[] memory targets = new address[](1);
    targets[0] = address(guardianAdministrator);

    uint256[] memory values = new uint256[](1);
    values[0] = 0;

    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeCall(guardianAdministrator.guardianApprove, (guardian));

    string memory description =
      string.concat("Guardian application: ", guardian.toHexString(), " block: ", detail.blockRequest.toString());
    bytes32 descriptionHash = keccak256(bytes(description));

    governor.queue(targets, values, calldatas, descriptionHash);
    vm.warp(block.timestamp + timeLock.getMinDelay() + 1);
    vm.roll(block.number + 1);
    governor.execute(targets, values, calldatas, descriptionHash);

    vm.prank(address(timeLock));
    guardianAdministrator.banGuardian(guardian);

    assertFalse(guardianAdministrator.isActiveGuardian(guardian));
    assertEq(bondToken.balanceOf(treasury), MIN_STAKE);
  }
}
