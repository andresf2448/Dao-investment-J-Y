// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {InvestmentDaoDeploymentBase} from "../../script/deploy/InvestmentDaoDeploymentBase.s.sol";
import {TimeLock} from "../../contracts/governance/TimeLock.sol";

contract InvestmentDaoBootstrapHarness is InvestmentDaoDeploymentBase {
  function scheduleFromCurrentSender(TimeLock timeLock, address target, bytes memory data, bytes32 salt)
    external
    returns (bytes32 operationId, bool executed)
  {
    return _scheduleAndMaybeExecuteFromCurrentSender(timeLock, target, data, salt);
  }

  function executeReadyFromCurrentSender(TimeLock timeLock, address target, bytes memory data, bytes32 salt)
    external
    returns (bytes32 operationId, bool executed)
  {
    return _executeReadyOperationFromCurrentSender(timeLock, target, data, salt);
  }

  function vaultFactorySalt() external pure returns (bytes32) {
    return VAULT_FACTORY_SALT;
  }
}
