// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MockERC20} from "../../test/mocks/MockERC20.sol";
import {MockAavePool} from "../../test/mocks/MockAavePool.sol";
import {MockCompoundComet} from "../../test/mocks/MockCompoundComet.sol";
import {MockV3AggregatorLocal} from "../../test/mocks/MockV3AggregatorLocal.sol";

contract DeployMocks is Script {
  function run()
    external
    returns (address mockERC20, address mockAavePool, address mockCompoundComet, address mockV3Aggregator)
  {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;

    vm.startBroadcast(deployerPrivateKey);
    MockERC20 mockERC20Instance = new MockERC20("USDTGenesis", "USDTG", 18);
    MockERC20 unlinkedTestToken = new MockERC20("StandaloneTestToken", "STAND", 18);
    MockAavePool mockAavePoolInstance = new MockAavePool();
    MockCompoundComet mockCompoundCometInstance = new MockCompoundComet();
    MockV3AggregatorLocal mockV3AggregatorInstance = new MockV3AggregatorLocal(8, 1e8);
    vm.stopBroadcast();

    console.log("USDTGenesis deployed at:", address(mockERC20Instance));
    console.log("StandaloneTestToken deployed at:", address(unlinkedTestToken));
    console.log("MockAavePool deployed at:", address(mockAavePoolInstance));
    console.log("MockCompoundComet deployed at:", address(mockCompoundCometInstance));
    console.log("MockV3Aggregator deployed at:", address(mockV3AggregatorInstance));

    return (
      address(mockERC20Instance),
      address(mockAavePoolInstance),
      address(mockCompoundCometInstance),
      address(mockV3AggregatorInstance)
    );
  }
}
