// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {TimeLock} from "../../contracts/governance/TimeLock.sol";

contract DeployTimeLock is Script {
  function run(address _deployer) external returns (TimeLock) {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    address deployer = _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;

    address[] memory proposers = new address[](1);
    address[] memory executors = new address[](1);

    proposers[0] = deployer;
    executors[0] = deployer;

    vm.startBroadcast(deployerPrivateKey);
      TimeLock timeLock = new TimeLock({
        minDelay: 10,
        proposers: proposers,
        executors: executors,
        admin: deployer
      });
    vm.stopBroadcast();

    console.log("TimeLock deployed at:", address(timeLock));
    return timeLock;
  }
}