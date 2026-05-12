// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// =============================================================
//                           IMPORTS
// =============================================================
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IStrategyAdapter} from "../interfaces/adapters/IStrategyAdapter.sol";
import {IRiskManager} from "../interfaces/execution/IRiskManager.sol";
import {IStrategyRouter} from "../interfaces/execution/IStrategyRouter.sol";
import {IVaultRegistry} from "../interfaces/vaults/IVaultRegistry.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title StrategyRouter
/// @notice Routes invest and divest calls from vaults to approved strategy adapters.
/// @dev Enforces adapter allowlist and integrates with RiskManager pre-checks before investing.
contract StrategyRouter is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IStrategyRouter {

  /*//////////////////////////////////////////////////////////////
                              TYPE DECLARATIONS
  //////////////////////////////////////////////////////////////*/
  
  using EnumerableSet for EnumerableSet.AddressSet;
  using Address for address payable;

  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @notice Role allowed to manage adapter allowlist.
  bytes32 public constant ADAPTER_MANAGER_ROLE = keccak256("ADAPTER_MANAGER_ROLE");

  /// @notice Action code used by adapters for investing.
  uint8 public constant INVEST_ACTION = 0;

  /// @notice Action code used by adapters for divesting.
  uint8 public constant DIVEST_ACTION = 1;

  /// @notice Vault registry used to validate vault status.
  IVaultRegistry public vaultRegistry;

  /// @notice Risk manager used to validate execution conditions.
  address public riskManager;

  /// @dev Adapter allowlist.
  EnumerableSet.AddressSet private _allowedAdapters;

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when adapter allowlist status changes.
  event AdapterAllowedSet(address indexed adapter, bool allowed);

  /// @notice Emitted when risk manager dependency is updated.
  event RiskManagerUpdated(address indexed oldRiskManager, address indexed newRiskManager);

  /// @notice Emitted when a batch strategy action is executed.
  event StrategyExecuted(
    address indexed vault, address[] adapters, address indexed asset, uint256[] amounts, uint8 action
  );

  /// @notice Emitted when a batch divest action is executed.
  event DivestStrategy(address indexed vault, address[] adapters, uint256[] amountsToDivest);

  /*//////////////////////////////////////////////////////////////
                                  ERRORS
  //////////////////////////////////////////////////////////////*/
  /// @notice Thrown when adapter is not allowlisted.
  error StrategyRouter__AdapterNotAllowed();

  /// @notice Thrown when vault is not active in registry.
  error StrategyRouter__VaultNotActive();

  /// @notice Thrown when adapter/amount arrays are invalid or duplicated.
  error StrategyRouter__InvalidAllocation();

  /// @notice Thrown when contract native balance is insufficient for withdrawal.
  error StrategyRouter__InsufficientNativeBalance();

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /// @dev Locks implementation contract by disabling initializer calls.
  constructor() {
    _disableInitializers();
  }

  /// @notice Withdraws native token balance from the contract.
  /// @param to Recipient address.
  /// @param amount Amount of native token to withdraw.
  function withdrawNative(address payable to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (to == address(0)) revert CommonErrors.ZeroAddress();
    if (amount == 0) revert CommonErrors.ZeroAmount();
    if (address(this).balance < amount) revert StrategyRouter__InsufficientNativeBalance();

    to.sendValue(amount);
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @notice Initializes router dependencies and role assignments.
  /// @param adminTimelock Address receiving admin and adapter manager roles.
  /// @param riskManager_ Risk manager contract used for pre-execution validation.
  /// @param vaultRegistry_ Registry used to confirm vault activity.
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

  /// @notice Adds or removes an adapter from the router allowlist.
  /// @param adapter Adapter contract address.
  /// @param isAllow True to allow, false to remove.
  function setAdapterAllowed(address adapter, bool isAllow) external onlyRole(ADAPTER_MANAGER_ROLE) {
    if (adapter == address(0)) revert CommonErrors.ZeroAddress();

    if (isAllow) {
      _allowedAdapters.add(adapter);
    } else {
      _allowedAdapters.remove(adapter);
    }

    emit AdapterAllowedSet(adapter, isAllow);
  }

  // ==========================================================
  //                           PUBLIC
  // ==========================================================

  /// @inheritdoc IStrategyRouter
  function isAdapterAllowed(address adapter) public view returns (bool) {
    return _allowedAdapters.contains(adapter);
  }

  /// @inheritdoc IStrategyRouter
  function getAllowedAdapters() external view returns (address[] memory) {
    return _allowedAdapters.values();
  }

  /// @notice Updates the risk manager dependency.
  /// @param newRiskManager New risk manager contract.
  function setRiskManager(address newRiskManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (newRiskManager == address(0)) revert CommonErrors.ZeroAddress();

    address oldRiskManager = riskManager;
    riskManager = newRiskManager;

    emit RiskManagerUpdated(oldRiskManager, newRiskManager);
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @inheritdoc IStrategyRouter
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

    bool[] memory validAdapters = new bool[](length);

    for (uint256 i = 0; i < length; i++) {
      address adapter = adapters[i];

      if (adapter == address(0) || !_allowedAdapters.contains(adapter)) {
        validAdapters[i] = false;
        continue;
      }

      bool isDuplicate = false;
      for (uint256 j = 0; j < i; j++) {
        if (adapters[j] == adapter) {
          isDuplicate = true;
          break;
        }
      }

      if (isDuplicate) {
        validAdapters[i] = false;
      } else {
        validAdapters[i] = true;
      }
    }

    for (uint256 i = 0; i < length; i++) {
      if (!validAdapters[i]) continue;

      uint256 amount = amountsToInvest[i];

      if (amount == 0) continue;

      IStrategyAdapter(adapters[i]).execute(vault, action, amount);
    }

    emit StrategyExecuted(vault, adapters, asset, amountsToInvest, action);
  }

  /// @inheritdoc IStrategyRouter
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

      if (adapter == address(0) || !_allowedAdapters.contains(adapter)) continue;

      uint256 amount = amountsToDivest[i];

      if (amount == 0) continue;

      IStrategyAdapter(adapter).execute(vault, DIVEST_ACTION, amount);
    }

    emit DivestStrategy(vault, adapters, amountsToDivest);
  }

  // ==========================================================
  //                          INTERNAL
  // ==========================================================

  /// @dev Validates vault state and risk checks before investment execution.
  /// @param vault Vault requesting execution.
  /// @param asset Asset to validate against risk manager.
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

  /// @dev Restricts UUPS upgrades to default admin role.
  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
