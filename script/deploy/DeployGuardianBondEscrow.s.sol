// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {GuardianBondEscrow} from "../../contracts/guardians/GuardianBondEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployGuardianBondEscrow is Script {
  function run(address _treasury, address _guardianAdmin, address _timeLock, address _token, address _deployer) external returns (GuardianBondEscrow) {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    address deployer = _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;
    address token = _token == address(0) ? networkConfig.allowedGenesisTokens[0] : _token;

    if (_treasury == address(0) || _guardianAdmin == address(0) || _timeLock == address(0)) {
      console.log("Error: Dependencies address required");
      revert("Dependencies not provided");
    }

    vm.startBroadcast(deployerPrivateKey);
      GuardianBondEscrow guardianBondEscrow = new GuardianBondEscrow({
        guardianApplicationToken_: IERC20(token),
        treasury_: payable(_treasury),
        adminTimelock: payable(_timeLock),
        guardianAdministrator_: _guardianAdmin
      });
    vm.stopBroadcast();

    console.log("GuardianBondEscrow deployed at:", address(guardianBondEscrow));
    return guardianBondEscrow;
  }
}