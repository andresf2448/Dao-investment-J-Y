// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import {IStrategyAdapter} from "../interfaces/adapters/IStrategyAdapter.sol";
import {IRiskManager} from "../interfaces/execution/IRiskManager.sol";
import {IStrategyRouter} from "../interfaces/execution/IStrategyRouter.sol";

contract StrategyRouter is
  Initializable,
  AccessControlUpgradeable,
  UUPSUpgradeable,
  IStrategyRouter
{
  bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
  bytes32 public constant ADAPTER_MANAGER_ROLE = keccak256("ADAPTER_MANAGER_ROLE");

  mapping(address adapter => bool allowed) public allowedAdapters;
  address public riskManager;

  event AdapterAllowedSet(address indexed adapter, bool allowed);
  event RiskManagerUpdated(address indexed oldRiskManager, address indexed newRiskManager);
  event StrategyExecuted(
    address indexed vault,
    address indexed adapter,
    address indexed asset,
    bytes data
  );

  error StrategyRouter__ZeroAddress();
  error StrategyRouter__AdapterNotAllowed();
  error StrategyRouter__RiskManagerNotSet();

  constructor() {
    _disableInitializers();
  }

  function initilize(
    address admin_,
    address riskManager_
  ) external initializer {
    if(admin_ == address(0) || riskManager_ == address(0)) {
      revert StrategyRouter__ZeroAddress();
    }

    __AccessControl_init();

    riskManager = riskManager_;

    _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    _grantRole(ADAPTER_MANAGER_ROLE, admin_);
  }

  function setAdapterAllowed(
    address adapter,
    bool allowed
  ) external onlyRole(ADAPTER_MANAGER_ROLE) {
    if(adapter == address(0))
      revert StrategyRouter__ZeroAddress();

      allowedAdapters[adapter] = allowed;
  }

  function setRiskManager(
    address newRiskManager
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if(newRiskManager == address(0))
      revert StrategyRouter__ZeroAddress();

    address oldRiskManager = riskManager;
    riskManager = newRiskManager;

    emit RiskManagerUpdated(oldRiskManager, newRiskManager);
  }

  function execute(
    address adapter,
    address vault,
    address asset,
    bytes calldata data
  ) external override onlyRole(VAULT_ROLE) {
    if(!allowedAdapters[adapter])
      revert StrategyRouter__AdapterNotAllowed();

    if(riskManager == address(0))
      revert StrategyRouter__RiskManagerNotSet();

    IRiskManager(riskManager).validateExecution(vault, asset, adapter, data);
    IStrategyAdapter(adapter).execute(vault, data);

    emit StrategyExecuted(vault, adapter, asset, data);
  }

  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}