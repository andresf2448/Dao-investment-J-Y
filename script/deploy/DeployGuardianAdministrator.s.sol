// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {GuardianAdministrator} from "../../contracts/guardians/GuardianAdministrator.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract DeployGuardianAdministrator is Script {
  function run(address _daoGovernor, address _timeLock, address _deployer) external returns (GuardianAdministrator) {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    address deployer = _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;

    if (_daoGovernor == address(0) || _timeLock == address(0)) {
      console.log("Error: DaoGovernor or TimeLock address required");
      revert("Dependencies not provided");
    }

    vm.startBroadcast(deployerPrivateKey);
      GuardianAdministrator guardianAdministrator = new GuardianAdministrator({
        governor_: IGovernor(_daoGovernor),
        timelock_: _timeLock,
        minStake_: 100
      });
    vm.stopBroadcast();

    console.log("GuardianAdministrator deployed at:", address(guardianAdministrator));
    return guardianAdministrator;
  }
}