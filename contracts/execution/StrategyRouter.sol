// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IStrategyAdapter} from "../interfaces/adapters/IStrategyAdapter.sol";
import {IRiskManager} from "../interfaces/execution/IRiskManager.sol";
import {IStrategyRouter} from "../interfaces/execution/IStrategyRouter.sol";
import {IVaultRegistry} from "../interfaces/vaults/IVaultRegistry.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";

contract StrategyRouter is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IStrategyRouter {
  using EnumerableSet for EnumerableSet.AddressSet;

  bytes32 public constant ADAPTER_MANAGER_ROLE = keccak256("ADAPTER_MANAGER_ROLE");

  uint8 public constant INVEST_ACTION = 0;
  uint8 public constant DIVEST_ACTION = 1;

  IVaultRegistry public vaultRegistry;
  address public riskManager;

  EnumerableSet.AddressSet private _allowedAdapters;

  event AdapterAllowedSet(address indexed adapter, bool allowed);
  event RiskManagerUpdated(address indexed oldRiskManager, address indexed newRiskManager);

  event StrategyExecuted(
    address indexed vault, address[] adapters, address indexed asset, uint256[] amounts, uint8 action
  );

  event DivestStrategy(address indexed vault, address[] adapters, uint256[] amountsToDivest);

  error StrategyRouter__AdapterNotAllowed();
  error StrategyRouter__VaultNotActive();
  error StrategyRouter__InvalidAllocation();

  constructor() {
    _disableInitializers();
  }

  function initialize(address adminTimelock, address riskManager_, IVaultRegistry vaultRegistry_)
    external
    initializer
  {
    if (adminTimelock == address(0) || riskManager_ == address(0) || address(vaultRegistry_) == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    __AccessControl_init();

    riskManager = riskManager_;
    vaultRegistry = vaultRegistry_;

    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock);
    _grantRole(ADAPTER_MANAGER_ROLE, adminTimelock);
  }

  function setAdapterAllowed(address adapter, bool allowed) external onlyRole(ADAPTER_MANAGER_ROLE) {
    if (adapter == address(0)) revert CommonErrors.ZeroAddress();

    if (allowed) {
      _allowedAdapters.add(adapter);
    } else {
      _allowedAdapters.remove(adapter);
    }

    emit AdapterAllowedSet(adapter, allowed);
  }

  function isAdapterAllowed(address adapter) public view returns (bool) {
    return _allowedAdapters.contains(adapter);
  }

  function getAllowedAdapters() external view returns (address[] memory) {
    return _allowedAdapters.values();
  }

  function setRiskManager(address newRiskManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (newRiskManager == address(0)) revert CommonErrors.ZeroAddress();

    address oldRiskManager = riskManager;
    riskManager = newRiskManager;

    emit RiskManagerUpdated(oldRiskManager, newRiskManager);
  }

  function executeMultiple(
    address vault,
    address asset,
    address[] calldata adapters,
    uint256[] calldata amountsToInvest,
    uint8 action
  ) external override {
    if (vault != msg.sender) revert CommonErrors.Unauthorized();

    uint256 length = adapters.length;

    if (length == 0 || length != amountsToInvest.length) {
      revert StrategyRouter__InvalidAllocation();
    }

    _validateVaultAndRisk(vault, asset);

    for (uint256 i = 0; i < length; i++) {
      address adapter = adapters[i];

      _validateAdapter(adapter);

      for (uint256 j = 0; j < i; j++) {
        if (adapters[j] == adapter) {
          revert StrategyRouter__InvalidAllocation();
        }
      }
    }

    for (uint256 i = 0; i < length; i++) {
      uint256 amount = amountsToInvest[i];

      if (amount == 0) continue;

      IStrategyAdapter(adapters[i]).execute(vault, action, amount);
    }

    emit StrategyExecuted(vault, adapters, asset, amountsToInvest, action);
  }

  function divestMultiple(address vault, address[] calldata adapters, uint256[] calldata amountsToDivest)
    external
    override
  {
    if (vault != msg.sender) revert CommonErrors.Unauthorized();

    uint256 length = adapters.length;

    if (length == 0 || length != amountsToDivest.length) {
      revert StrategyRouter__InvalidAllocation();
    }

    if (vault == address(0)) revert CommonErrors.ZeroAddress();

    if (!vaultRegistry.isActiveVault(vault)) {
      revert StrategyRouter__VaultNotActive();
    }

    for (uint256 i = 0; i < length; i++) {
      address adapter = adapters[i];

      _validateAdapter(adapter);

      uint256 amount = amountsToDivest[i];

      if (amount == 0) continue;

      IStrategyAdapter(adapter).execute(vault, DIVEST_ACTION, amount);
    }

    emit DivestStrategy(vault, adapters, amountsToDivest);
  }

  function _validateVaultAndRisk(address vault, address asset) internal view {
    if (vault == address(0) || asset == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    if (!vaultRegistry.isActiveVault(vault)) {
      revert StrategyRouter__VaultNotActive();
    }

    if (riskManager == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    IRiskManager(riskManager).validateExecution(asset);
  }

  function _validateAdapter(address adapter) internal view {
    if (adapter == address(0)) revert CommonErrors.ZeroAddress();

    if (!_allowedAdapters.contains(adapter)) {
      revert StrategyRouter__AdapterNotAllowed();
    }
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
