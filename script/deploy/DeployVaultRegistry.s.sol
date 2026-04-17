// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VaultRegistry} from "../../contracts/vaults/registry/VaultRegistry.sol";

contract DeployVaultRegistry is Script {
  function run(address _timeLock, address _deployer) external returns (VaultRegistry) {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    address deployer = _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;

    if (_timeLock == address(0)) {
      console.log("Error: TimeLock address required");
      revert("TimeLock not provided");
    }

    vm.startBroadcast(deployerPrivateKey);
      VaultRegistry vaultRegistry = new VaultRegistry({
        adminTimelock: payable(_timeLock)
      });
    vm.stopBroadcast();

    console.log("VaultRegistry deployed at:", address(vaultRegistry));
    return vaultRegistry;
  }
}