pragma solidity ^0.8.33;

import {Script} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract DeployToken is Script {
    function run() external {
        vm.startBroadcast();
        new TestToken();
        vm.stopBroadcast();
    }
}