// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/deploy/HelperConfig.s.sol";
import {DeployInvestmentDao} from "../../script/deploy/DeployInvestmentDao.s.sol";
import {DeployMocks} from "../../script/deploy/DeployMocks.s.sol";
import {InvestmentDaoDeploymentBase} from "../../script/deploy/InvestmentDaoDeploymentBase.s.sol";
import {TimeLock} from "../../contracts/governance/TimeLock.sol";
import {DaoGovernor} from "../../contracts/governance/DaoGovernor.sol";
import {GovernanceToken} from "../../contracts/governance/GovernanceToken.sol";
import {GuardianAdministrator} from "../../contracts/guardians/GuardianAdministrator.sol";
import {VaultRegistry} from "../../contracts/vaults/registry/VaultRegistry.sol";

contract DeployInvestmentDaoHarness is DeployInvestmentDao {
    function deployForTest()
        external
        returns (
            TimeLock timeLock,
            GovernanceToken governanceToken,
            address treasury,
            address daoGovernor,
            address protocolCore,
            address riskManager,
            address guardianAdministrator,
            address guardianBondEscrow,
            address vaultRegistry,
            address strategyRouter,
            address vaultImplementation,
            address genesisBonding,
            address vaultFactory,
            address aaveV3Adapter,
            address compoundV3Adapter
        )
    {
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

        DeployMocks deployMocks = new DeployMocks();
        (address mockERC20, address mockAavePool, address mockCompoundComet, address mockV3Aggregator) =
            deployMocks.run();

        networkConfig.allowedGenesisTokens[0] = mockERC20;
        networkConfig.allowedVaultToken = mockERC20;
        networkConfig.aavePool = mockAavePool;
        networkConfig.compoundComet = mockCompoundComet;
        networkConfig.mockV3Aggregator = mockV3Aggregator;

        return deployContracts(config, vm.addr(networkConfig.deployerPrivateKey), networkConfig);
    }
}

contract InvestmentDaoBootstrapHarness is InvestmentDaoDeploymentBase {
    function scheduleFromCurrentSender(TimeLock timeLock, address target, bytes memory data, bytes32 salt)
        external
        returns (bytes32 operationId, bool executed)
    {
        return _scheduleAndMaybeExecuteFromCurrentSender(timeLock, target, data, salt);
    }

    function executeReadyFromCurrentSender(TimeLock timeLock, address target, bytes memory data, bytes32 salt)
        external
        returns (bytes32 operationId, bool executed)
    {
        return _executeReadyOperationFromCurrentSender(timeLock, target, data, salt);
    }

    function vaultFactorySalt() external pure returns (bytes32) {
        return VAULT_FACTORY_SALT;
    }
}

contract DeployInvestmentDaoTest is Test {
    uint256 private constant BLOCK_TIME = 12;
    uint256 private constant NONZERO_DELAY = 1 days;

    TimeLock private timeLock;
    GovernanceToken private governanceToken;
    address private treasury;
    address private daoGovernor;
    address private protocolCore;
    address private riskManager;
    address private guardianAdministrator;
    address private guardianBondEscrow;
    address private vaultRegistry;
    address private strategyRouter;
    address private vaultImplementation;
    address private genesisBonding;
    address private vaultFactory;
    address private aaveV3Adapter;
    address private compoundV3Adapter;

    function setUp() public {
        vm.roll(100);
        vm.warp(100);

        DeployInvestmentDaoHarness deployInvestmentDao = new DeployInvestmentDaoHarness();

        (
            timeLock,
            governanceToken,
            treasury,
            daoGovernor,
            protocolCore,
            riskManager,
            guardianAdministrator,
            guardianBondEscrow,
            vaultRegistry,
            strategyRouter,
            vaultImplementation,
            genesisBonding,
            vaultFactory,
            aaveV3Adapter,
            compoundV3Adapter
        ) = deployInvestmentDao.deployForTest();

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + BLOCK_TIME);
    }

    function testAnvilDeploysEveryContract() public view {
        assertNotEq(address(timeLock), address(0));
        assertNotEq(address(governanceToken), address(0));
        assertNotEq(treasury, address(0));
        assertNotEq(daoGovernor, address(0));
        assertNotEq(protocolCore, address(0));
        assertNotEq(riskManager, address(0));
        assertNotEq(guardianAdministrator, address(0));
        assertNotEq(guardianBondEscrow, address(0));
        assertNotEq(vaultRegistry, address(0));
        assertNotEq(strategyRouter, address(0));
        assertNotEq(vaultImplementation, address(0));
        assertNotEq(genesisBonding, address(0));
        assertNotEq(vaultFactory, address(0));
        assertNotEq(aaveV3Adapter, address(0));
        assertNotEq(compoundV3Adapter, address(0));
    }

    function testAnvilBootstrapExecutesImmediately() public view {
        assertEq(address(GuardianAdministrator(guardianAdministrator).bondEscrow()), guardianBondEscrow);
        assertTrue(VaultRegistry(vaultRegistry).hasRole(VaultRegistry(vaultRegistry).FACTORY_ROLE(), vaultFactory));
    }

    function testGovernorReceivesTimelockRoles() public view {
        assertTrue(timeLock.hasRole(timeLock.PROPOSER_ROLE(), daoGovernor));
        assertTrue(timeLock.hasRole(timeLock.EXECUTOR_ROLE(), daoGovernor));
        assertTrue(timeLock.hasRole(timeLock.CANCELLER_ROLE(), daoGovernor));
    }

    function testGuardianAdministratorHasSnapshotVotingPower() public view {
        uint256 proposalThreshold = DaoGovernor(payable(daoGovernor)).proposalThreshold();

        assertEq(governanceToken.getVotes(guardianAdministrator), proposalThreshold);
        assertEq(governanceToken.getPastVotes(guardianAdministrator, block.number - 1), proposalThreshold);
    }

    function testNonZeroDelayBootstrapWaitsBeforeExecution() public {
        InvestmentDaoBootstrapHarness harness = new InvestmentDaoBootstrapHarness();

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(harness);
        executors[0] = address(harness);

        TimeLock delayedTimeLock =
            new TimeLock({minDelay: NONZERO_DELAY, proposers: proposers, executors: executors, admin: address(this)});
        VaultRegistry delayedVaultRegistry = new VaultRegistry(address(delayedTimeLock));
        address expectedFactory = makeAddr("expectedFactory");
        bytes memory data = abi.encodeWithSelector(VaultRegistry.setFactory.selector, expectedFactory);
        bytes32 salt = harness.vaultFactorySalt();

        (bytes32 operationId, bool executed) =
            harness.scheduleFromCurrentSender(delayedTimeLock, address(delayedVaultRegistry), data, salt);

        assertFalse(executed);
        assertTrue(delayedTimeLock.isOperationPending(operationId));
        assertFalse(delayedTimeLock.isOperationReady(operationId));
        assertFalse(delayedVaultRegistry.hasRole(delayedVaultRegistry.FACTORY_ROLE(), expectedFactory));

        vm.expectRevert(bytes("Timelock operation not ready"));
        harness.executeReadyFromCurrentSender(delayedTimeLock, address(delayedVaultRegistry), data, salt);

        vm.warp(block.timestamp + NONZERO_DELAY + 1);
        vm.roll(block.number + 1);

        (bytes32 executedOperationId, bool executedAfterDelay) =
            harness.executeReadyFromCurrentSender(delayedTimeLock, address(delayedVaultRegistry), data, salt);

        assertEq(executedOperationId, operationId);
        assertTrue(executedAfterDelay);
        assertTrue(delayedTimeLock.isOperationDone(operationId));
        assertTrue(delayedVaultRegistry.hasRole(delayedVaultRegistry.FACTORY_ROLE(), expectedFactory));
    }
}
