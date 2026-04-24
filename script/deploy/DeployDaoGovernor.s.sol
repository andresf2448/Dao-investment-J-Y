// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DaoGovernor} from "../../contracts/governance/DaoGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimeLock} from "../../contracts/governance/TimeLock.sol";

contract DeployDaoGovernor is Script {
  uint32 internal constant ANVIL_VOTING_PERIOD = 20;
  uint32 internal constant DEFAULT_VOTING_PERIOD = 45818;

  function run(HelperConfig config, address _governanceToken, address _timeLock, address _deployer) external returns (DaoGovernor) {
    HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

    uint256 deployerPrivateKey = networkConfig.deployerPrivateKey;
    address deployer = _deployer == address(0) ? vm.addr(deployerPrivateKey) : _deployer;
    uint32 votingPeriod = block.chainid == 31337 ? ANVIL_VOTING_PERIOD : DEFAULT_VOTING_PERIOD;

    if (_governanceToken == address(0) || _timeLock == address(0)) {
      console.log("Error: GovernanceToken or TimeLock address required");
      revert("Dependencies not provided");
    }

    vm.startBroadcast(deployerPrivateKey);
      DaoGovernor daoGovernor = new DaoGovernor({
        governanceToken: IVotes(_governanceToken),
        timelock: TimeLock(payable(_timeLock)),
        minProposalThreshold_: 1000e18,
        minVotingDelay_: 1,
        minVotingPeriod_: votingPeriod
      });
    vm.stopBroadcast();

    console.log("DaoGovernor deployed at:", address(daoGovernor));
    console.log("DaoGovernor voting period:", votingPeriod);
    return daoGovernor;
  }
}
