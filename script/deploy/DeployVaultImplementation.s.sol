// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VaultImplementation} from "../../contracts/vaults/implementations/VaultImplementation.sol";

contract DeployVaultImplementation is Script {
  function run(address _deployer) external returns (VaultImplementation) {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    address deployer = _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;

    vm.startBroadcast(deployerPrivateKey);
      VaultImplementation vaultImplementation = new VaultImplementation();
    vm.stopBroadcast();

    console.log("VaultImplementation deployed at:", address(vaultImplementation));
    return vaultImplementation;
  }
}