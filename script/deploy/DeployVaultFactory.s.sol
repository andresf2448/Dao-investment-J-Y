// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VaultFactory} from "../../contracts/vaults/factory/VaultFactory.sol";

contract DeployVaultFactory is Script {
  function run(
    address _timeLock,
    address _vaultImpl,
    address _guardianAdmin,
    address _vaultRegistry,
    address _strategyRouter,
    address _protocolCore,
    address _deployer
  ) external returns (VaultFactory) {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    address deployer = _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;

    if (_timeLock == address(0) || _vaultImpl == address(0) || _guardianAdmin == address(0) ||
        _vaultRegistry == address(0) || _strategyRouter == address(0) || _protocolCore == address(0)) {
      console.log("Error: Dependencies address required");
      revert("Dependencies not provided");
    }

    vm.startBroadcast(deployerPrivateKey);
      VaultFactory vaultFactory = new VaultFactory({
        adminTimelock_: payable(_timeLock),
        implementation_: _vaultImpl,
        guardianAdministrator_: _guardianAdmin,
        vaultRegistry_: _vaultRegistry,
        router_: _strategyRouter,
        core_: _protocolCore
      });
    vm.stopBroadcast();

    console.log("VaultFactory deployed at:", address(vaultFactory));
    return vaultFactory;
  }
}