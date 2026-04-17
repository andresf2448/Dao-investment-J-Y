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

contract DeployInvestmentDao is Script {
  function run() external {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();
    address deployer = vm.addr(networkConfig.deployerPrivateKey);

    (
      address timeLock,
      address governanceToken,
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
      address,
      address,
      address
    )
  {
    console.log("========================================");
    console.log("Deploying Investment DAO Protocol");
    console.log("========================================");

    DeployTimeLock deployTimeLock = new DeployTimeLock();
    deployTimeLock.run(deployer);
    address timeLock = deployTimeLock.timeLockAddress();

    DeployGovernanceToken deployGovernanceToken = new DeployGovernanceToken();
    deployGovernanceToken.run(deployer);
    address governanceToken = deployGovernanceToken.governanceTokenAddress();

    DeployTreasury deployTreasury = new DeployTreasury();
    deployTreasury.run(timeLock, deployer);
    address treasury = deployTreasury.treasuryAddress();

    DeployGenesisBonding deployGenesisBonding = new DeployGenesisBonding();
    deployGenesisBonding.run(
      governanceToken,
      treasury,
      deployer,
      networkConfig.allowedGenesisTokens
    );
    address genesisBonding = deployGenesisBonding.genesisBondingAddress();

    vm.startPrank(deployer);
      deployGovernanceToken.grantRole(deployGovernanceToken.MINTER_ROLE(), deployGenesisBonding.genesisBondingAddress());
      deployGovernanceToken.grantRole(deployGovernanceToken.DEFAULT_ADMIN_ROLE(), timeLock);
      deployGovernanceToken.revokeRole(deployGovernanceToken.DEFAULT_ADMIN_ROLE(), deployer);
    vm.stopPrank();

    DeployDaoGovernor deployDaoGovernor = new DeployDaoGovernor();
    deployDaoGovernor.run(governanceToken, timeLock, deployer);
    address daoGovernor = deployDaoGovernor.daoGovernorAddress();

    DeployProtocolCore deployProtocolCore = new DeployProtocolCore();
    deployProtocolCore.run(timeLock, deployer, networkConfig.allowedGenesisTokens);
    address protocolCore = deployProtocolCore.protocolCoreAddress();

    DeployRiskManager deployRiskManager = new DeployRiskManager();
    deployRiskManager.run(timeLock, deployer);
    address riskManager = deployRiskManager.riskManagerAddress();

    DeployGuardianAdministrator deployGuardianAdministrator = new DeployGuardianAdministrator();
    deployGuardianAdministrator.run(daoGovernor, timeLock, deployer);
    address guardianAdministrator = deployGuardianAdministrator.guardianAdministratorAddress();

    DeployGuardianBondEscrow deployGuardianBondEscrow = new DeployGuardianBondEscrow();
    deployGuardianBondEscrow.run(
      treasury,
      guardianAdministrator,
      timeLock,
      networkConfig.allowedGenesisTokens[0],
      deployer
    );
    address guardianBondEscrow = deployGuardianBondEscrow.guardianBondEscrowAddress();

    DeployVaultRegistry deployVaultRegistry = new DeployVaultRegistry();
    deployVaultRegistry.run(timeLock, deployer);
    address vaultRegistry = deployVaultRegistry.vaultRegistryAddress();

    DeployStrategyRouter deployStrategyRouter = new DeployStrategyRouter();
    deployStrategyRouter.run(timeLock, riskManager, vaultRegistry, deployer);
    address strategyRouter = deployStrategyRouter.strategyRouterAddress();

    DeployVaultImplementation deployVaultImplementation = new DeployVaultImplementation();
    deployVaultImplementation.run(deployer);
    address vaultImplementation = deployVaultImplementation.vaultImplementationAddress();

    DeployVaultFactory deployVaultFactory = new DeployVaultFactory();
    deployVaultFactory.run(
      timeLock,
      vaultImplementation,
      guardianAdministrator,
      vaultRegistry,
      strategyRouter,
      protocolCore,
      deployer
    );
    address vaultFactory = deployVaultFactory.vaultFactoryAddress();

    DeployAaveV3Adapter deployAaveV3Adapter = new DeployAaveV3Adapter();
    deployAaveV3Adapter.run(strategyRouter, networkConfig.aavePool, deployer);
    address aaveV3Adapter = deployAaveV3Adapter.aaveV3AdapterAddress();

    console.log("========================================");
    console.log("Deployment Summary:");
    console.log("========================================");
    console.log("TimeLock:", timeLock);
    console.log("GovernanceToken:", governanceToken);
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
    address timeLock,
    address governanceToken,
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
    vm.serializeAddress(json, "timeLock", timeLock);
    vm.serializeAddress(json, "governanceToken", governanceToken);
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