// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {RiskManager} from "../../contracts/execution/RiskManager.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployRiskManager is Script {
  function run(address _timeLock, address _deployer) external returns (RiskManager) {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    address deployer = _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;

    if (_timeLock == address(0)) {
      console.log("Error: TimeLock address required");
      revert("TimeLock not provided");
    }

    vm.startBroadcast(deployerPrivateKey);
      RiskManager implementation = new RiskManager();
      ERC1967Proxy proxy = new ERC1967Proxy(
        address(implementation),
        abi.encodeCall(
          RiskManager.initialize,
          (payable(_timeLock), deployer)
        )
      );
    vm.stopBroadcast();

    console.log("RiskManager deployed at:", address(proxy));
    return RiskManager(address(proxy));
  }
}