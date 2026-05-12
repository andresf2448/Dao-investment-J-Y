// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {TimeLock} from "../../../contracts/governance/TimeLock.sol";
import {GovernanceToken} from "../../../contracts/governance/GovernanceToken.sol";
import {DaoGovernor} from "../../../contracts/governance/DaoGovernor.sol";
import {ProtocolCore} from "../../../contracts/core/ProtocolCore.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GovernanceExecutionFlowTest is Test {
  TimeLock internal timeLock;
  GovernanceToken internal governanceToken;
  DaoGovernor internal governor;
  ProtocolCore internal protocolCore;

  address internal voter = makeAddr("voter");
  address internal emergency = makeAddr("emergency");

  uint256 internal constant PROPOSAL_THRESHOLD = 100e18;
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

    MockERC20 genesis = new MockERC20("Genesis", "GEN", 18);
    address[] memory allowedGenesisTokens = new address[](1);
    allowedGenesisTokens[0] = address(genesis);

    ProtocolCore coreImplementation = new ProtocolCore();
    protocolCore = ProtocolCore(
      address(
        new ERC1967Proxy(
          address(coreImplementation),
          abi.encodeCall(ProtocolCore.initialize, (payable(address(timeLock)), emergency, allowedGenesisTokens, address(genesis)))
        )
      )
    );

    governanceToken.grantRole(governanceToken.MINTER_ROLE(), address(this));
    governanceToken.mint(voter, PROPOSAL_THRESHOLD * 2);

    vm.prank(voter);
    governanceToken.delegate(voter);

    vm.roll(block.number + 1);
  }

  function testGovernanceProposalQueuesAndExecutesProtocolCoreChange() public {
    // Test: flujo completo propose -> vote -> queue -> execute sobre ProtocolCore.
    address newAsset = makeAddr("newAsset");
    string memory description = "Enable new vault asset";

    address[] memory targets = new address[](1);
    targets[0] = address(protocolCore);

    uint256[] memory values = new uint256[](1);
    values[0] = 0;

    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeCall(protocolCore.setSupportedVaultAsset, (newAsset, true));

    vm.prank(voter);
    uint256 proposalId = governor.propose(targets, values, calldatas, description);

    uint256 snapshot = governor.proposalSnapshot(proposalId);
    uint256 deadline = governor.proposalDeadline(proposalId);

    vm.roll(snapshot + 1);

    vm.prank(voter);
    governor.castVote(proposalId, 1);

    vm.roll(deadline + 1);

    bytes32 descriptionHash = keccak256(bytes(description));
    governor.queue(targets, values, calldatas, descriptionHash);

    vm.warp(block.timestamp + timeLock.getMinDelay() + 1);

    governor.execute(targets, values, calldatas, descriptionHash);

    assertTrue(protocolCore.isVaultAssetSupported(newAsset));
  }
}
