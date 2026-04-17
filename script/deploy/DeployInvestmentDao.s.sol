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
import {TimeLock} from "../../contracts/governance/TimeLock.sol";
import {GovernanceToken} from "../../contracts/governance/GovernanceToken.sol";

contract DeployInvestmentDao is Script {
  function run() external {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();
    address deployer = vm.addr(networkConfig.deployerPrivateKey);

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
    ) = deployContracts(deployer, networkConfig);

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

  function deployContracts(address deployer, HelperConfig.NetworkConfig memory networkConfig)
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
    TimeLock timeLock = deployTimeLock.run(deployer);

    DeployGovernanceToken deployGovernanceToken = new DeployGovernanceToken();
    GovernanceToken governanceToken = deployGovernanceToken.run(deployer);

    DeployTreasury deployTreasury = new DeployTreasury();
    address treasury = address(deployTreasury.run(address(timeLock), deployer));

    DeployGenesisBonding deployGenesisBonding = new DeployGenesisBonding();
    address genesisBonding = address(deployGenesisBonding.run(
      address(governanceToken),
      treasury,
      deployer,
      networkConfig.allowedGenesisTokens
    ));

    vm.startPrank(deployer);
    governanceToken.grantRole(governanceToken.MINTER_ROLE(), genesisBonding);
    governanceToken.grantRole(governanceToken.DEFAULT_ADMIN_ROLE(), address(timeLock));
    governanceToken.revokeRole(governanceToken.DEFAULT_ADMIN_ROLE(), deployer);
    vm.stopPrank();

    DeployDaoGovernor deployDaoGovernor = new DeployDaoGovernor();
    address daoGovernor = address(deployDaoGovernor.run(address(governanceToken), address(timeLock), deployer));

    DeployProtocolCore deployProtocolCore = new DeployProtocolCore();
    address protocolCore = address(deployProtocolCore.run(address(timeLock), deployer, networkConfig.allowedGenesisTokens));

    DeployRiskManager deployRiskManager = new DeployRiskManager();
    address riskManager = address(deployRiskManager.run(address(timeLock), deployer));

    DeployGuardianAdministrator deployGuardianAdministrator = new DeployGuardianAdministrator();
    address guardianAdministrator = address(deployGuardianAdministrator.run(daoGovernor, address(timeLock), deployer));

    DeployGuardianBondEscrow deployGuardianBondEscrow = new DeployGuardianBondEscrow();
    address guardianBondEscrow = address(deployGuardianBondEscrow.run(
      treasury,
      guardianAdministrator,
      address(timeLock),
      networkConfig.allowedGenesisTokens[0],
      deployer
    ));

    DeployVaultRegistry deployVaultRegistry = new DeployVaultRegistry();
    address vaultRegistry = address(deployVaultRegistry.run(address(timeLock), deployer));

    DeployStrategyRouter deployStrategyRouter = new DeployStrategyRouter();
    address strategyRouter = address(deployStrategyRouter.run(address(timeLock), riskManager, vaultRegistry, deployer));

    DeployVaultImplementation deployVaultImplementation = new DeployVaultImplementation();
    address vaultImplementation = address(deployVaultImplementation.run(deployer));

    DeployVaultFactory deployVaultFactory = new DeployVaultFactory();
    address vaultFactory = address(deployVaultFactory.run(
      address(timeLock),
      vaultImplementation,
      guardianAdministrator,
      vaultRegistry,
      strategyRouter,
      protocolCore,
      deployer
    ));

    DeployAaveV3Adapter deployAaveV3Adapter = new DeployAaveV3Adapter();
    address aaveV3Adapter = address(deployAaveV3Adapter.run(strategyRouter, networkConfig.aavePool, deployer));

    console.log("========================================");
    console.log("Deployment Summary:");
    console.log("========================================");
    console.log("TimeLock:", address(timeLock));
    console.log("GovernanceToken:", address(governanceToken));
    console.log("Treasury:", treasury);
    console.log("DaoGovernor:", daoGovernor);
    console.log("ProtocolCore:", protocolCore);
    console.log("RiskManager:", riskManager);
    console.log("GuardianAdministrator:", guardianAdministrator);
    console.log("GuardianBondEscrow:", guardianBondEscrow);
    console.log("VaultRegistry:", vaultRegistry);
    console.log("StrategyRouter:", strategyRouter);
    console.log("VaultImplementation:", vaultImplementation);
    console.log("GenesisBonding:", genesisBonding);
    console.log("VaultFactory:", vaultFactory);
    console.log("AaveV3Adapter:", aaveV3Adapter);
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