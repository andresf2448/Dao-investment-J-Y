// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {InvestmentDaoDeploymentBase} from "./InvestmentDaoDeploymentBase.s.sol";
import {TimeLock} from "../../contracts/governance/TimeLock.sol";

contract FinalizeInvestmentDaoDeployment is InvestmentDaoDeploymentBase {
  struct DeploymentSnapshot {
    uint256 chainId;
    uint256 timelockMinDelay;
    bytes32 bondEscrowOperationId;
    bytes32 vaultFactoryOperationId;
    bool bootstrapExecuted;
    address aavePool;
    address compoundComet;
    address mockV3Aggregator;
    address timeLock;
    address governanceToken;
    address treasury;
    address daoGovernor;
    address protocolCore;
    address riskManager;
    address guardianAdministrator;
    address guardianBondEscrow;
    address vaultRegistry;
    address strategyRouter;
    address vaultImplementation;
    address genesisBonding;
    address vaultFactory;
    address aaveV3Adapter;
    address compoundV3Adapter;
  }

  function run() external {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();
    string memory path = _deploymentPath(networkConfig.networkName);
    DeploymentSnapshot memory deployment = _loadDeployment(path);
    TimeLock timeLock = TimeLock(payable(deployment.timeLock));

    require(deployment.chainId == block.chainid, "Deployment chainId mismatch");
    require(deployment.timelockMinDelay == timeLock.getMinDelay(), "Timelock minDelay mismatch");
    require(
      deployment.bondEscrowOperationId
        == _operationId(
          timeLock,
          deployment.guardianAdministrator,
          _bondEscrowData(deployment.guardianBondEscrow),
          BOND_ESCROW_SALT
        ),
      "Bond escrow operation mismatch"
    );
    require(
      deployment.vaultFactoryOperationId
        == _operationId(
          timeLock, deployment.vaultRegistry, _vaultFactoryData(deployment.vaultFactory), VAULT_FACTORY_SALT
        ),
      "Vault factory operation mismatch"
    );

    vm.startBroadcast(networkConfig.deployerPrivateKey);
    _executeReadyOperationFromCurrentSender(
      timeLock, deployment.guardianAdministrator, _bondEscrowData(deployment.guardianBondEscrow), BOND_ESCROW_SALT
    );

    _executeReadyOperationFromCurrentSender(
      timeLock, deployment.vaultRegistry, _vaultFactoryData(deployment.vaultFactory), VAULT_FACTORY_SALT
    );

    if (block.chainid != 31337) {
      _cleanupDeployerTimelockRolesFromCurrentSender(timeLock, vm.addr(networkConfig.deployerPrivateKey));
    }
    vm.stopBroadcast();

    deployment.bootstrapExecuted = true;
    _writeDeployment(path, deployment);

    console.log("Investment DAO deployment finalized for:", networkConfig.networkName);
  }

  function _deploymentPath(string memory networkName) internal pure returns (string memory) {
    return string.concat("deployments/", networkName, ".json");
  }

  function _loadDeployment(string memory path) internal view returns (DeploymentSnapshot memory deployment) {
    string memory json = vm.readFile(path);

    deployment = DeploymentSnapshot({
      chainId: vm.parseJsonUint(json, ".chainId"),
      timelockMinDelay: vm.parseJsonUint(json, ".timelockMinDelay"),
      bondEscrowOperationId: vm.parseJsonBytes32(json, ".bondEscrowOperationId"),
      vaultFactoryOperationId: vm.parseJsonBytes32(json, ".vaultFactoryOperationId"),
      bootstrapExecuted: vm.parseJsonBool(json, ".bootstrapExecuted"),
      aavePool: vm.parseJsonAddress(json, ".aavePool"),
      compoundComet: vm.parseJsonAddress(json, ".compoundComet"),
      mockV3Aggregator: vm.parseJsonAddress(json, ".mockV3Aggregator"),
      timeLock: vm.parseJsonAddress(json, ".timeLock"),
      governanceToken: vm.parseJsonAddress(json, ".governanceToken"),
      treasury: vm.parseJsonAddress(json, ".treasury"),
      daoGovernor: vm.parseJsonAddress(json, ".daoGovernor"),
      protocolCore: vm.parseJsonAddress(json, ".protocolCore"),
      riskManager: vm.parseJsonAddress(json, ".riskManager"),
      guardianAdministrator: vm.parseJsonAddress(json, ".guardianAdministrator"),
      guardianBondEscrow: vm.parseJsonAddress(json, ".guardianBondEscrow"),
      vaultRegistry: vm.parseJsonAddress(json, ".vaultRegistry"),
      strategyRouter: vm.parseJsonAddress(json, ".strategyRouter"),
      vaultImplementation: vm.parseJsonAddress(json, ".vaultImplementation"),
      genesisBonding: vm.parseJsonAddress(json, ".genesisBonding"),
      vaultFactory: vm.parseJsonAddress(json, ".vaultFactory"),
      aaveV3Adapter: vm.parseJsonAddress(json, ".aaveV3Adapter"),
      compoundV3Adapter: vm.parseJsonAddress(json, ".compoundV3Adapter")
    });
  }

  function _writeDeployment(string memory path, DeploymentSnapshot memory deployment) internal {
    string memory json = "deployment";
    vm.serializeUint(json, "chainId", deployment.chainId);
    vm.serializeUint(json, "timelockMinDelay", deployment.timelockMinDelay);
    vm.serializeBytes32(json, "bondEscrowOperationId", deployment.bondEscrowOperationId);
    vm.serializeBytes32(json, "vaultFactoryOperationId", deployment.vaultFactoryOperationId);
    vm.serializeBool(json, "bootstrapExecuted", deployment.bootstrapExecuted);
    vm.serializeAddress(json, "aavePool", deployment.aavePool);
    vm.serializeAddress(json, "compoundComet", deployment.compoundComet);
    vm.serializeAddress(json, "mockV3Aggregator", deployment.mockV3Aggregator);
    vm.serializeAddress(json, "timeLock", deployment.timeLock);
    vm.serializeAddress(json, "governanceToken", deployment.governanceToken);
    vm.serializeAddress(json, "treasury", deployment.treasury);
    vm.serializeAddress(json, "daoGovernor", deployment.daoGovernor);
    vm.serializeAddress(json, "protocolCore", deployment.protocolCore);
    vm.serializeAddress(json, "riskManager", deployment.riskManager);
    vm.serializeAddress(json, "guardianAdministrator", deployment.guardianAdministrator);
    vm.serializeAddress(json, "guardianBondEscrow", deployment.guardianBondEscrow);
    vm.serializeAddress(json, "vaultRegistry", deployment.vaultRegistry);
    vm.serializeAddress(json, "strategyRouter", deployment.strategyRouter);
    vm.serializeAddress(json, "vaultImplementation", deployment.vaultImplementation);
    vm.serializeAddress(json, "genesisBonding", deployment.genesisBonding);
    vm.serializeAddress(json, "vaultFactory", deployment.vaultFactory);
    vm.serializeAddress(json, "aaveV3Adapter", deployment.aaveV3Adapter);
    string memory finalJson = vm.serializeAddress(json, "compoundV3Adapter", deployment.compoundV3Adapter);

    vm.writeJson(finalJson, path);
  }
}
