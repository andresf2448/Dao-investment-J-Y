// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {DeployInvestmentDao} from "../../script/deploy/DeployInvestmentDao.s.sol";
import {DeployMocks} from "../../script/deploy/DeployMocks.s.sol";
import {HelperConfig} from "../../script/deploy/HelperConfig.s.sol";
import {GovernanceToken} from "../../contracts/governance/GovernanceToken.sol";
import {TimeLock} from "../../contracts/governance/TimeLock.sol";

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
