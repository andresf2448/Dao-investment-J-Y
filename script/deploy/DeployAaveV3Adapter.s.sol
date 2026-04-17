// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {AaveV3Adapter} from "../../contracts/adapters/aave/AaveV3Adapter.sol";

contract DeployAaveV3Adapter is Script {
  function run(address _strategyRouter, address _pool, address _deployer) external returns (AaveV3Adapter) {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    address deployer = _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;
    address pool = _pool == address(0) ? networkConfig.aavePool : _pool;

    if (_strategyRouter == address(0)) {
      console.log("Error: StrategyRouter address required");
      revert("StrategyRouter not provided");
    }

    vm.startBroadcast(deployerPrivateKey);
      AaveV3Adapter aaveV3Adapter = new AaveV3Adapter({
        router_: _strategyRouter,
        pool_: pool
      });
    vm.stopBroadcast();

    console.log("AaveV3Adapter deployed at:", address(aaveV3Adapter));
    return aaveV3Adapter;
  }
}