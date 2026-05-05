// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {TimeLock} from "../../contracts/governance/TimeLock.sol";
import {GuardianAdministrator} from "../../contracts/guardians/GuardianAdministrator.sol";
import {VaultRegistry} from "../../contracts/vaults/registry/VaultRegistry.sol";

abstract contract InvestmentDaoDeploymentBase is Script {
  bytes32 internal constant BOND_ESCROW_SALT = keccak256("deploy-set-bond-escrow");
  bytes32 internal constant VAULT_FACTORY_SALT = keccak256("deploy-set-vault-factory");
  bytes32 internal constant TIMELOCK_PREDECESSOR = bytes32(0);

  function _bondEscrowData(address guardianBondEscrow) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(GuardianAdministrator.setBondEscrow.selector, guardianBondEscrow);
  }

  function _vaultFactoryData(address vaultFactory) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(VaultRegistry.setFactory.selector, vaultFactory);
  }

  function _operationId(TimeLock timeLock, address target, bytes memory data, bytes32 salt)
    internal
    pure
    returns (bytes32)
  {
    return timeLock.hashOperation(target, 0, data, TIMELOCK_PREDECESSOR, salt);
  }

  function _scheduleAndMaybeExecute(
    uint256 deployerPrivateKey,
    TimeLock timeLock,
    address target,
    bytes memory data,
    bytes32 salt
  ) internal returns (bytes32 operationId, bool executed) {
    vm.startBroadcast(deployerPrivateKey);
    (operationId, executed) = _scheduleAndMaybeExecuteFromCurrentSender(timeLock, target, data, salt);
    vm.stopBroadcast();

    if (!executed) {
      console.log("Timelock operation scheduled and pending execution for target:", target);
      console.logBytes32(operationId);
    }
  }

  function _scheduleAndMaybeExecuteFromCurrentSender(
    TimeLock timeLock,
    address target,
    bytes memory data,
    bytes32 salt
  ) internal returns (bytes32 operationId, bool executed) {
    uint256 minDelay = timeLock.getMinDelay();
    operationId = _operationId(timeLock, target, data, salt);
    bool alreadyScheduled = timeLock.isOperation(operationId);

    if (!alreadyScheduled) {
      timeLock.schedule(target, 0, data, TIMELOCK_PREDECESSOR, salt, minDelay);
    }

    if (minDelay == 0 && !alreadyScheduled) {
      timeLock.execute(target, 0, data, TIMELOCK_PREDECESSOR, salt);
      executed = true;
    }
  }

  function _executeReadyOperationFromCurrentSender(TimeLock timeLock, address target, bytes memory data, bytes32 salt)
    internal
    returns (bytes32 operationId, bool executed)
  {
    operationId = _operationId(timeLock, target, data, salt);

    if (timeLock.isOperationDone(operationId)) {
      return (operationId, false);
    }

    require(timeLock.isOperationReady(operationId), "Timelock operation not ready");

    timeLock.execute(target, 0, data, TIMELOCK_PREDECESSOR, salt);
    executed = true;
  }

  function _grantGovernorTimelockRolesFromCurrentSender(TimeLock timeLock, address daoGovernor) internal {
    if (!timeLock.hasRole(timeLock.PROPOSER_ROLE(), daoGovernor)) {
      timeLock.grantRole(timeLock.PROPOSER_ROLE(), daoGovernor);
    }
    if (!timeLock.hasRole(timeLock.EXECUTOR_ROLE(), daoGovernor)) {
      timeLock.grantRole(timeLock.EXECUTOR_ROLE(), daoGovernor);
    }
    if (!timeLock.hasRole(timeLock.CANCELLER_ROLE(), daoGovernor)) {
      timeLock.grantRole(timeLock.CANCELLER_ROLE(), daoGovernor);
    }
  }

  function _cleanupDeployerTimelockRolesFromCurrentSender(TimeLock timeLock, address deployer) internal {
    if (timeLock.hasRole(timeLock.PROPOSER_ROLE(), deployer)) {
      timeLock.revokeRole(timeLock.PROPOSER_ROLE(), deployer);
    }
    if (timeLock.hasRole(timeLock.CANCELLER_ROLE(), deployer)) {
      timeLock.revokeRole(timeLock.CANCELLER_ROLE(), deployer);
    }
    if (timeLock.hasRole(timeLock.EXECUTOR_ROLE(), deployer)) {
      timeLock.revokeRole(timeLock.EXECUTOR_ROLE(), deployer);
    }
    if (timeLock.hasRole(timeLock.DEFAULT_ADMIN_ROLE(), deployer)) {
      timeLock.renounceRole(timeLock.DEFAULT_ADMIN_ROLE(), deployer);
    }
  }
}
