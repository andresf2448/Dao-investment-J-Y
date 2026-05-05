// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {GuardianAdministrator} from "../../contracts/guardians/GuardianAdministrator.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract DeployGuardianAdministrator is Script {
  function run(HelperConfig config, address _daoGovernor, address _timeLock, address token)
    external
    returns (GuardianAdministrator)
  {
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;

    if (_daoGovernor == address(0) || _timeLock == address(0)) {
      console.log("Error: DaoGovernor or TimeLock address required");
      revert("Dependencies not provided");
    }

    vm.startBroadcast(deployerPrivateKey);
    GuardianAdministrator guardianAdministrator = new GuardianAdministrator({
      governor_: IGovernor(_daoGovernor),
      timelock_: _timeLock,
      minStake_: 100 * (10 ** IERC20Metadata(token).decimals()) // Example: 100 tokens with decimals
    });
    vm.stopBroadcast();

    console.log("GuardianAdministrator deployed at:", address(guardianAdministrator));
    return guardianAdministrator;
  }
}
