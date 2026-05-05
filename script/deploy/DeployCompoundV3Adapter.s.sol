// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CompoundV3Adapter} from "../../contracts/adapters/compound/CompoundV3Adapter.sol";

contract DeployCompoundV3Adapter is Script {
  function run(HelperConfig config, address _strategyRouter, address _comet, address _deployer)
    external
    returns (CompoundV3Adapter)
  {
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;
    address comet = _comet == address(0) ? networkConfig.compoundComet : _comet;

    if (_strategyRouter == address(0)) {
      console.log("Error: StrategyRouter address required");
      revert("StrategyRouter not provided");
    }

    vm.startBroadcast(deployerPrivateKey);
    CompoundV3Adapter compoundV3Adapter = new CompoundV3Adapter({router_: _strategyRouter, comet_: comet});
    vm.stopBroadcast();

    console.log("CompoundV3Adapter deployed at:", address(compoundV3Adapter));
    return compoundV3Adapter;
  }
}
