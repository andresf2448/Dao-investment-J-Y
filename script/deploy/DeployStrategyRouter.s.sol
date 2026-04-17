// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {StrategyRouter} from "../../contracts/execution/StrategyRouter.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IVaultRegistry} from "../../contracts/interfaces/vaults/IVaultRegistry.sol";

contract DeployStrategyRouter is Script {
  function run(address _timeLock, address _riskManager, address _vaultRegistry, address _deployer) external returns (StrategyRouter) {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    address deployer = _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;

    if (_timeLock == address(0) || _riskManager == address(0) || _vaultRegistry == address(0)) {
      console.log("Error: Dependencies address required");
      revert("Dependencies not provided");
    }

    vm.startBroadcast(deployerPrivateKey);
      StrategyRouter implementation = new StrategyRouter();
      ERC1967Proxy proxy = new ERC1967Proxy(
        address(implementation),
        abi.encodeCall(
          StrategyRouter.initialize,
          (payable(_timeLock), _riskManager, IVaultRegistry(_vaultRegistry))
        )
      );
    vm.stopBroadcast();

    console.log("StrategyRouter deployed at:", address(proxy));
    return StrategyRouter(address(proxy));
  }
}