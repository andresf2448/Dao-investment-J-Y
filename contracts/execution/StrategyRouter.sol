// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IStrategyAdapter} from "../interfaces/adapters/IStrategyAdapter.sol";
import {IRiskManager} from "../interfaces/execution/IRiskManager.sol";
import {IStrategyRouter} from "../interfaces/execution/IStrategyRouter.sol";
import {IVaultRegistry} from "../interfaces/vaults/IVaultRegistry.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";

contract StrategyRouter is
  Initializable,
  AccessControlUpgradeable,
  UUPSUpgradeable,
  IStrategyRouter
{
  bytes32 public constant ADAPTER_MANAGER_ROLE = keccak256("ADAPTER_MANAGER_ROLE");
  IVaultRegistry public vaultRegistry;

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

  error StrategyRouter__AdapterNotAllowed();
  error StrategyRouter__VaultNotActive();

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address adminTimelock,
    address riskManager_,
    IVaultRegistry vaultRegistry_
  ) external initializer {
    if(adminTimelock == address(0) || riskManager_ == address(0))
      revert CommonErrors.ZeroAddress();
    
    if(address(vaultRegistry_) == address(0))
      revert CommonErrors.ZeroAddress();

    __AccessControl_init();

    riskManager = riskManager_;
    vaultRegistry = vaultRegistry_;
    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock);
    _grantRole(ADAPTER_MANAGER_ROLE, adminTimelock);
  }

  function setAdapterAllowed(
    address adapter,
    bool allowed
  ) external onlyRole(ADAPTER_MANAGER_ROLE) {
    if(adapter == address(0))
      revert CommonErrors.ZeroAddress();

      allowedAdapters[adapter] = allowed;
  }

  function setRiskManager(
    address newRiskManager
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if(newRiskManager == address(0))
      revert CommonErrors.ZeroAddress();

    address oldRiskManager = riskManager;
    riskManager = newRiskManager;

    emit RiskManagerUpdated(oldRiskManager, newRiskManager);
  }

  function execute(
    address adapter,
    address vault,
    address asset,
    bytes calldata data
  ) external override {
    if(vault != msg.sender)
      revert CommonErrors.Unauthorized();

    if(!vaultRegistry.isActiveVault(vault))
      revert StrategyRouter__VaultNotActive();

    if(!allowedAdapters[adapter])
      revert StrategyRouter__AdapterNotAllowed();

    if(riskManager == address(0))
      revert CommonErrors.ZeroAddress();

    IRiskManager(riskManager).validateExecution(vault, asset, adapter, data);
    IStrategyAdapter(adapter).execute(vault, data);

    emit StrategyExecuted(vault, adapter, asset, data);
  }

  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}