// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {GenesisBonding} from "../../contracts/bootstrap/GenesisBonding.sol";
import {IGovernanceToken} from "../../contracts/interfaces/governance/IGovernanceToken.sol";

contract DeployGenesisBonding is Script {
  function run(address _governanceToken, address _treasury, address _deployer, address[] memory _allowedTokens) external returns (GenesisBonding) {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    address deployer = _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;
    address[] memory allowedTokens = _allowedTokens.length > 0 ? _allowedTokens : networkConfig.allowedGenesisTokens;

    if (_governanceToken == address(0) || _treasury == address(0)) {
      console.log("Error: Dependencies address required");
      revert("Dependencies not provided");
    }

    vm.startBroadcast(deployerPrivateKey);
      GenesisBonding genesisBonding = new GenesisBonding({
        adminTimelock: deployer,
        sweepRole: deployer,
        allowedGenesisTokens: allowedTokens,
        governanceToken_: IGovernanceToken(_governanceToken),
        treasury_: payable(_treasury),
        rate_: 100
      });
    vm.stopBroadcast();

    console.log("GenesisBonding deployed at:", address(genesisBonding));
    return genesisBonding;
  }
}