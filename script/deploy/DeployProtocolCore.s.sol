// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ProtocolCore} from "../../contracts/core/ProtocolCore.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployProtocolCore is Script {
  function run(address _timeLock, address _deployer, address[] memory _allowedTokens) external returns (ProtocolCore) {
    HelperConfig config = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    address deployer = _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;
    address[] memory allowedTokens = _allowedTokens.length > 0 ? _allowedTokens : networkConfig.allowedGenesisTokens;

    if (_timeLock == address(0)) {
      console.log("Error: TimeLock address required");
      revert("TimeLock not provided");
    }

    vm.startBroadcast(deployerPrivateKey);
      ProtocolCore implementation = new ProtocolCore();
      ERC1967Proxy proxy = new ERC1967Proxy(
        address(implementation),
        abi.encodeCall(
          ProtocolCore.initialize,
          (payable(_timeLock), deployer, allowedTokens)
        )
      );
    vm.stopBroadcast();

    console.log("ProtocolCore deployed at:", address(proxy));
    return ProtocolCore(address(proxy));
  }
}