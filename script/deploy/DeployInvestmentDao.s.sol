// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DeployTimeLock} from "./DeployTimeLock.s.sol";
import {DeployGovernanceToken} from "./DeployGovernanceToken.s.sol";
import {DeployTreasury} from "./DeployTreasury.s.sol";
import {DeployDaoGovernor} from "./DeployDaoGovernor.s.sol";
import {DeployProtocolCore} from "./DeployProtocolCore.s.sol";
import {DeployRiskManager} from "./DeployRiskManager.s.sol";
import {DeployGuardianAdministrator} from "./DeployGuardianAdministrator.s.sol";
import {DeployGuardianBondEscrow} from "./DeployGuardianBondEscrow.s.sol";
import {DeployVaultRegistry} from "./DeployVaultRegistry.s.sol";
import {DeployStrategyRouter} from "./DeployStrategyRouter.s.sol";
import {DeployVaultImplementation} from "./DeployVaultImplementation.s.sol";
import {DeployGenesisBonding} from "./DeployGenesisBonding.s.sol";
import {DeployVaultFactory} from "./DeployVaultFactory.s.sol";
import {DeployAaveV3Adapter} from "./DeployAaveV3Adapter.s.sol";
import {DeployMocks} from "./DeployMocks.s.sol";
import {TimeLock} from "../../contracts/governance/TimeLock.sol";
import {DaoGovernor} from "../../contracts/governance/DaoGovernor.sol";
import {GovernanceToken} from "../../contracts/governance/GovernanceToken.sol";
import {GuardianAdministrator} from "../../contracts/guardians/GuardianAdministrator.sol";
import {VaultRegistry} from "../../contracts/vaults/registry/VaultRegistry.sol";

contract DeployInvestmentDao is Script {
  function run() external {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();
    address deployer = vm.addr(networkConfig.deployerPrivateKey);

    // Deploy mocks for anvil network
    if (block.chainid == 31337) { // Anvil chain ID
      DeployMocks deployMocks = new DeployMocks();
      (address mockERC20, address mockAavePool) = deployMocks.run();

      // Update network config with deployed mock addresses
      networkConfig.allowedGenesisTokens[0] = mockERC20;
      networkConfig.allowedVaultToken = mockERC20;
      networkConfig.aavePool = mockAavePool;
    }

    (
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
      address aaveV3Adapter
    ) = deployContracts(config, deployer, networkConfig);

    generateDeploymentsJson(
      networkConfig,
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
      aaveV3Adapter
    );

    createContractsSdkStructure();
  }

  function deployContracts(HelperConfig config, address deployer, HelperConfig.NetworkConfig memory networkConfig)
    internal
    returns (
      TimeLock,
      GovernanceToken,
      address,
      address,
      address,
      address,
      address,
      address,
      address,
      address,
      address,
      address,
      address,
      address
    )
  {
    console.log("========================================");
    console.log("Deploying Investment DAO Protocol");
    console.log("========================================");

    DeployTimeLock deployTimeLock = new DeployTimeLock();
    TimeLock timeLock = deployTimeLock.run(config, deployer);

    DeployGovernanceToken deployGovernanceToken = new DeployGovernanceToken();
    GovernanceToken governanceToken = deployGovernanceToken.run(config, deployer);

    DeployTreasury deployTreasury = new DeployTreasury();
    address treasury = address(deployTreasury.run(config, address(timeLock), deployer));

    DeployGenesisBonding deployGenesisBonding = new DeployGenesisBonding();
    address genesisBonding = address(deployGenesisBonding.run(
      config,
      address(governanceToken),
      treasury,
      deployer,
      networkConfig.allowedGenesisTokens
    ));

    DeployDaoGovernor deployDaoGovernor = new DeployDaoGovernor();
    address daoGovernor = address(deployDaoGovernor.run(config, address(governanceToken), address(timeLock), deployer));

    DeployProtocolCore deployProtocolCore = new DeployProtocolCore();
    address protocolCore = address(deployProtocolCore.run(config, address(timeLock), deployer, networkConfig.allowedGenesisTokens, networkConfig.allowedVaultToken));

    DeployRiskManager deployRiskManager = new DeployRiskManager();
    address riskManager = address(deployRiskManager.run(config, address(timeLock), deployer));

    DeployGuardianAdministrator deployGuardianAdministrator = new DeployGuardianAdministrator();
    address guardianAdministrator = address(deployGuardianAdministrator.run(config, daoGovernor, address(timeLock), deployer));

    vm.startBroadcast(networkConfig.deployerPrivateKey);
      governanceToken.grantRole(governanceToken.MINTER_ROLE(), genesisBonding);
      governanceToken.grantRole(governanceToken.MINTER_ROLE(), deployer);
      governanceToken.mint(guardianAdministrator, DaoGovernor(payable(daoGovernor)).proposalThreshold());
      governanceToken.revokeRole(governanceToken.MINTER_ROLE(), deployer);
      governanceToken.grantRole(governanceToken.DEFAULT_ADMIN_ROLE(), address(timeLock));
      governanceToken.revokeRole(governanceToken.DEFAULT_ADMIN_ROLE(), deployer);
    vm.stopBroadcast();

    vm.startBroadcast(networkConfig.deployerPrivateKey);
      GuardianAdministrator(guardianAdministrator).selfDelegateGovernanceVotes(address(governanceToken));
    vm.stopBroadcast();

    DeployGuardianBondEscrow deployGuardianBondEscrow = new DeployGuardianBondEscrow();
    address guardianBondEscrow = address(deployGuardianBondEscrow.run(
      config,
      treasury,
      guardianAdministrator,
      address(timeLock),
      networkConfig.allowedGenesisTokens[0],
      deployer
    ));

    DeployVaultRegistry deployVaultRegistry = new DeployVaultRegistry();
    address vaultRegistry = address(deployVaultRegistry.run(config, address(timeLock), deployer));

    DeployStrategyRouter deployStrategyRouter = new DeployStrategyRouter();
    address strategyRouter =
      address(deployStrategyRouter.run(config, address(timeLock), riskManager, address(vaultRegistry), deployer));

    DeployVaultImplementation deployVaultImplementation = new DeployVaultImplementation();
    address vaultImplementation = address(deployVaultImplementation.run(config, deployer));

    DeployVaultFactory deployVaultFactory = new DeployVaultFactory();
    address vaultFactory = address(deployVaultFactory.run(
      config,
      address(timeLock),
      vaultImplementation,
      guardianAdministrator,
      vaultRegistry,
      strategyRouter,
      protocolCore,
      deployer
    ));

    DeployAaveV3Adapter deployAaveV3Adapter = new DeployAaveV3Adapter();
    address aaveV3Adapter = address(deployAaveV3Adapter.run(config, strategyRouter, networkConfig.aavePool, deployer));

    _configureProtocolDefaults(
      networkConfig,
      timeLock,
      guardianAdministrator,
      guardianBondEscrow,
      vaultRegistry,
      vaultFactory
    );

    vm.startBroadcast(networkConfig.deployerPrivateKey);
      timeLock.grantRole(timeLock.DEFAULT_ADMIN_ROLE(), daoGovernor);
      timeLock.renounceRole(timeLock.DEFAULT_ADMIN_ROLE(), deployer);
    vm.stopBroadcast();

    console.log("========================================");
    console.log("Deployment Summary:");
    console.log("========================================");
    console.log("TimeLock: ", address(timeLock));
    console.log("GovernanceToken: ", address(governanceToken));
    console.log("Treasury: ", treasury);
    console.log("DaoGovernor: ", daoGovernor);
    console.log("ProtocolCore: ", protocolCore);
    console.log("RiskManager: ", riskManager);
    console.log("GuardianAdministrator: ", guardianAdministrator);
    console.log("GuardianBondEscrow: ", guardianBondEscrow);
    console.log("VaultRegistry: ", vaultRegistry);
    console.log("StrategyRouter: ", strategyRouter);
    console.log("VaultImplementation: ", vaultImplementation);
    console.log("GenesisBonding: ", genesisBonding);
    console.log("VaultFactory: ", vaultFactory);
    console.log("AaveV3Adapter: ", aaveV3Adapter);
    console.log("================MOCK====================");
    if (block.chainid == 31337) {
      console.log("MockERC20: ", networkConfig.allowedGenesisTokens[0]);
      console.log("MockAavePool: ", networkConfig.aavePool);
    }
    console.log("========================================");

    return (
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
      aaveV3Adapter
    );
  }

  function _scheduleAndMaybeExecute(
    uint256 deployerPrivateKey,
    TimeLock timeLock,
    address target,
    bytes memory data,
    bytes32 salt
  ) internal {
    bytes32 predecessor = bytes32(0);
    uint256 minDelay = timeLock.getMinDelay();

    vm.startBroadcast(deployerPrivateKey);
    timeLock.schedule(target, 0, data, predecessor, salt, minDelay);

    if (minDelay == 0) {
      timeLock.execute(target, 0, data, predecessor, salt);
    }
    vm.stopBroadcast();

    if (minDelay > 0) {
      console.log("Timelock operation scheduled and pending execution for target:", target);
    }
  }

  function _configureProtocolDefaults(
    HelperConfig.NetworkConfig memory networkConfig,
    TimeLock timeLock,
    address guardianAdministrator,
    address guardianBondEscrow,
    address vaultRegistry,
    address vaultFactory
  ) internal {
    _scheduleAndMaybeExecute(
      networkConfig.deployerPrivateKey,
      timeLock,
      guardianAdministrator,
      abi.encodeWithSelector(GuardianAdministrator.setBondEscrow.selector, guardianBondEscrow),
      keccak256("deploy-set-bond-escrow")
    );

    _scheduleAndMaybeExecute(
      networkConfig.deployerPrivateKey,
      timeLock,
      vaultRegistry,
      abi.encodeWithSelector(VaultRegistry.setFactory.selector, vaultFactory),
      keccak256("deploy-set-vault-factory")
    );
  }

  function generateDeploymentsJson(
    HelperConfig.NetworkConfig memory networkConfig,
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
    address aaveV3Adapter
  ) internal {
    string memory deploymentsDir = "deployments";

    if (!vm.exists(deploymentsDir)) {
      vm.createDir(deploymentsDir, true);
    }

    string memory path = string.concat("deployments/", networkConfig.networkName, ".json");

    string memory json = "deployment";
    vm.serializeUint(json, "chainId", block.chainid);
    vm.serializeAddress(json, "aavePool", networkConfig.aavePool);
    vm.serializeAddress(json, "timeLock", address(timeLock));
    vm.serializeAddress(json, "governanceToken", address(governanceToken));
    vm.serializeAddress(json, "treasury", treasury);
    vm.serializeAddress(json, "daoGovernor", daoGovernor);
    vm.serializeAddress(json, "protocolCore", protocolCore);
    vm.serializeAddress(json, "riskManager", riskManager);
    vm.serializeAddress(json, "guardianAdministrator", guardianAdministrator);
    vm.serializeAddress(json, "guardianBondEscrow", guardianBondEscrow);
    vm.serializeAddress(json, "vaultRegistry", vaultRegistry);
    vm.serializeAddress(json, "strategyRouter", strategyRouter);
    vm.serializeAddress(json, "vaultImplementation", vaultImplementation);
    vm.serializeAddress(json, "genesisBonding", genesisBonding);
    vm.serializeAddress(json, "vaultFactory", vaultFactory);
    string memory finalJson = vm.serializeAddress(json, "aaveV3Adapter", aaveV3Adapter);

    vm.writeJson(finalJson, path);

    console.log("Deployment file written to:", path);
  }

  function createContractsSdkStructure() internal {
    string memory sdkRoot = "contracts-sdk/src";

    if (!vm.isDir(sdkRoot)) {
      vm.createDir(sdkRoot, true);
    }

    if (!vm.isDir(string.concat(sdkRoot, "/abi"))) {
      vm.createDir(string.concat(sdkRoot, "/abi"), true);
    }

    if (!vm.isDir(string.concat(sdkRoot, "/addresses"))) {
      vm.createDir(string.concat(sdkRoot, "/addresses"), true);
    }

    if (!vm.isDir(string.concat(sdkRoot, "/helpers"))) {
      vm.createDir(string.concat(sdkRoot, "/helpers"), true);
    }
  }
}
