// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// =============================================================
//                           IMPORTS
// =============================================================
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IProtocolCore} from "../../interfaces/core/IProtocolCore.sol";
import {IStrategyRouter} from "../../interfaces/execution/IStrategyRouter.sol";
import {IVaultStrategyExecutor} from "../../interfaces/vaults/IVaultStrategyExecutor.sol";
import {IStrategyAdapter} from "../../interfaces/adapters/IStrategyAdapter.sol";
import {CommonErrors} from "../../libraries/errors/CommonErrors.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title VaultImplementation
/// @notice ERC4626 vault with guardian-managed strategy allocation across adapters.
/// @dev Uses router-mediated execution and keeps adapter allocation state per vault clone.
contract VaultImplementation is
  Initializable,
  ERC20Upgradeable,
  ERC4626Upgradeable,
  AccessControlUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardTransient,
  IVaultStrategyExecutor
{

  /*//////////////////////////////////////////////////////////////
                              TYPE DECLARATIONS
  //////////////////////////////////////////////////////////////*/
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @notice 100% allocation expressed in basis points.
  uint16 public constant MAX_BPS = 10_000;

  /// @notice Action code used for investing through adapters.
  uint8 public constant INVEST_ACTION = 0;

  /// @notice Action code used for divesting through adapters.
  uint8 public constant DIVEST_ACTION = 1;

  /// @notice Role assigned to guardian strategy operator.
  bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

  /// @notice Role assigned to router and active adapters for execution callbacks.
  bytes32 public constant STRATEGY_EXECUTOR_ROLE = keccak256("STRATEGY_EXECUTOR_ROLE");

  /*//////////////////////////////////////////////////////////////
                              TYPE DECLARATIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Lifecycle status for an adapter in this vault.
  enum AdapterStatus {
    None,
    Active,
    Retired
  }

  /// @notice Allocation metadata tracked for each adapter.
  struct AdapterAllocation {
    /// @notice Allocation in basis points for active strategies.
    uint16 allocationBps;
    /// @notice Adapter lifecycle state.
    AdapterStatus status;
  }

  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  
  /// @notice Guardian assigned to this vault.
  address public guardian;

  /// @notice Factory that deployed and initialized this clone.
  address public factory;

  /// @notice Strategy router used for adapter execution.
  address public router;

  /// @notice Protocol core used for global pause checks.
  address public core;

  /// @dev Set of currently active adapters for this vault.
  EnumerableSet.AddressSet private _vaultActiveAdapters;

  /// @notice Adapter allocation state indexed by adapter address.
  mapping(address adapter => AdapterAllocation) public listAdapters;

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when vault clone initialization completes.
  event VaultInitialized(
    address indexed asset,
    address indexed guardian,
    address indexed admin,
    address factory,
    address router,
    address core
  );

  /// @notice Emitted when router dependency changes.
  event RouterUpdated(address indexed oldRouter, address indexed newRouter);

  /// @notice Emitted when core dependency changes.
  event CoreUpdated(address indexed oldCore, address indexed newCore);

  /// @notice Emitted when guardian submits a new allocation strategy.
  event StrategyExecutionRequest(address indexed guardian, address[] adapters, uint256[] allocationBps);

  /// @notice Emitted after a router-authorized external call is executed.
  event RouterCallExecuted(address indexed target, uint256 value, bytes data, bytes result);

  /// @notice Emitted when router updates token approval for an external spender.
  event RouterTokenApprovalSet(address indexed token, address indexed spender, uint256 amount);

  /*//////////////////////////////////////////////////////////////
                                  ERRORS
  //////////////////////////////////////////////////////////////*/
  /// @notice Thrown when initializer caller is not the declared factory.
  error VaultImplementation__NotFactory();

  /// @notice Thrown when deposits are globally paused in protocol core.
  error VaultImplementation__DepositsPaused();

  /// @notice Thrown when router-proxied external call fails without revert data.
  error VaultImplementation__ExternalCallFailed();

  /// @notice Thrown when strategy adapters/allocation arrays are malformed.
  error VaultImplementation__InvalidStrategyAllocation();

  /// @notice Thrown when an adapter appears more than once in strategy set.
  error VaultImplementation__DuplicatedAdapter();

  /// @notice Thrown when accumulated allocation exceeds 100%.
  error VaultImplementation__InvalidPercentage();

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

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @notice Initializes clone state and sets roles/dependencies.
  /// @param asset_ Vault underlying asset.
  /// @param name_ ERC20 name for vault shares.
  /// @param symbol_ ERC20 symbol for vault shares.
  /// @param guardian_ Guardian controlling strategy requests.
  /// @param adminTimelock Timelock that receives admin privileges.
  /// @param factory_ Factory address expected as initializer caller.
  /// @param router_ Strategy router contract.
  /// @param core_ Protocol core contract for pause checks.
  function initialize(
    address asset_,
    string memory name_,
    string memory symbol_,
    address guardian_,
    address adminTimelock,
    address factory_,
    address router_,
    address core_
  ) external initializer {
    if (
      asset_ == address(0) || guardian_ == address(0) || adminTimelock == address(0) || factory_ == address(0)
        || router_ == address(0) || core_ == address(0)
    ) {
      revert CommonErrors.ZeroAddress();
    }

    if (msg.sender != factory_) revert VaultImplementation__NotFactory();

    __ERC20_init(name_, symbol_);
    __ERC4626_init(IERC20(asset_));
    __AccessControl_init();
    __Pausable_init();

    guardian = guardian_;
    factory = factory_;
    router = router_;
    core = core_;

    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock);
    _grantRole(GUARDIAN_ROLE, guardian_);
    _grantRole(STRATEGY_EXECUTOR_ROLE, router_);

    emit VaultInitialized(asset_, guardian_, adminTimelock, factory_, router_, core_);
  }

  /// @notice Updates strategy router and rotates executor role.
  /// @param newRouter New router contract.
  function setRouter(address newRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (newRouter == address(0)) revert CommonErrors.ZeroAddress();

    address oldRouter = router;

    _revokeRole(STRATEGY_EXECUTOR_ROLE, oldRouter);
    router = newRouter;
    _grantRole(STRATEGY_EXECUTOR_ROLE, newRouter);

    emit RouterUpdated(oldRouter, newRouter);
  }

  /// @notice Updates core dependency used for protocol-level pause flags.
  /// @param newCore New protocol core contract.
  function setCore(address newCore) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (newCore == address(0)) revert CommonErrors.ZeroAddress();

    address oldCore = core;
    core = newCore;

    emit CoreUpdated(oldCore, newCore);
  }

  /// @notice Pauses user operations guarded by `whenNotPaused`.
  function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _pause();
  }

  /// @notice Unpauses user operations guarded by `whenNotPaused`.
  function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _unpause();
  }

  // ==========================================================
  //                           PUBLIC
  // ==========================================================

  /// @inheritdoc ERC4626Upgradeable
  /// @dev Reverts when protocol-wide vault deposits are paused in core.
  function deposit(uint256 assets, address receiver)
    public
    override
    whenNotPaused
    nonReentrant
    returns (uint256 shares)
  {
    if (IProtocolCore(core).isVaultDepositsPaused()) {
      revert VaultImplementation__DepositsPaused();
    }

    shares = super.deposit(assets, receiver);
  }

  /// @inheritdoc ERC4626Upgradeable
  /// @dev Reverts when protocol-wide vault deposits are paused in core.
  function mint(uint256 shares, address receiver)
    public
    override
    whenNotPaused
    nonReentrant
    returns (uint256 assets)
  {
    if (IProtocolCore(core).isVaultDepositsPaused()) {
      revert VaultImplementation__DepositsPaused();
    }

    assets = super.mint(shares, receiver);
  }

  /// @inheritdoc ERC4626Upgradeable
  /// @dev If idle liquidity is insufficient, divests from strategies before withdrawing and then rebalances.
  function withdraw(uint256 assets, address receiver, address owner)
    public
    override
    whenNotPaused
    nonReentrant
    returns (uint256 shares)
  {
    uint256 idleAssets = IERC20(asset()).balanceOf(address(this));

    if (assets > idleAssets) {
      _divestStrategy();
      shares = super.withdraw(assets, receiver, owner);

      _rebalanceStrategies();
    } else {
      shares = super.withdraw(assets, receiver, owner);
    }
  }

  /// @inheritdoc ERC4626Upgradeable
  /// @dev If idle liquidity is insufficient, divests before redeeming and then rebalances.
  function redeem(uint256 shares, address receiver, address owner)
    public
    override
    whenNotPaused
    nonReentrant
    returns (uint256 assets)
  {
    uint256 idleAssets = IERC20(asset()).balanceOf(address(this));

    if (previewRedeem(shares) > idleAssets) {
      _divestStrategy();
      assets = super.redeem(shares, receiver, owner);

      _rebalanceStrategies();
    } else {
      assets = super.redeem(shares, receiver, owner);
    }
  }

  /// @inheritdoc ERC4626Upgradeable
  /// @dev Sums idle vault balance plus assets currently deployed in active adapters.
  function totalAssets() public view override returns (uint256 total) {
    total = IERC20(asset()).balanceOf(address(this));

    uint256 length = _vaultActiveAdapters.length();

    for (uint256 i = 0; i < length; i++) {
      address adapter = _vaultActiveAdapters.at(i);
      total += IStrategyAdapter(adapter).totalAssets(address(this), asset());
    }
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @notice Sets a new target strategy allocation and executes requested action through router.
  /// @param newAdapters Adapter list that defines target strategy set.
  /// @param newAllocationBps Allocation list in basis points matching adapter indexes.
  /// @param action Adapter action selector (0 = invest, 1 = divest).
  function executeStrategy(address[] calldata newAdapters, uint256[] calldata newAllocationBps, uint8 action)
    external
    onlyRole(GUARDIAN_ROLE)
    whenNotPaused
  {
    _executeStrategy(newAdapters, newAllocationBps, action);
  }

  /// @notice Fully divests current active strategies.
  function divestStrategy() external onlyRole(GUARDIAN_ROLE) whenNotPaused {
    _divestStrategy();
  }

  /// @inheritdoc IVaultStrategyExecutor
  function executeFromRouter(address target, uint256 value, bytes calldata data)
    external
    override
    onlyRole(STRATEGY_EXECUTOR_ROLE)
    returns (bytes memory result)
  {
    if (target == address(0)) revert CommonErrors.ZeroAddress();

    (bool success, bytes memory returndata) = target.call{value: value}(data);

    if (!success) {
      _revertWithReturnData(returndata);
    }

    emit RouterCallExecuted(target, value, data, returndata);

    return returndata;
  }

  /// @inheritdoc IVaultStrategyExecutor
  function approveTokenFromRouter(address token, address spender, uint256 amount)
    external
    override
    onlyRole(STRATEGY_EXECUTOR_ROLE)
  {
    if (token == address(0) || spender == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    IERC20(token).forceApprove(spender, amount);

    emit RouterTokenApprovalSet(token, spender, amount);
  }

  /// @notice Returns active adapter list currently tracked by the vault.
  /// @return Active adapter addresses.
  function getActiveAdapters() external view returns (address[] memory) {
    return _vaultActiveAdapters.values();
  }

  // ==========================================================
  //                           PUBLIC
  // ==========================================================

  /// @inheritdoc ERC4626Upgradeable
  function decimals() public view override(ERC20Upgradeable, ERC4626Upgradeable) returns (uint8) {
    return ERC20Upgradeable.decimals();
  }

  /// @inheritdoc AccessControlUpgradeable
  function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  // ==========================================================
  //                          INTERNAL
  // ==========================================================

  /// @dev Validates strategy allocation, updates adapter registry, and executes router call.
  /// @param newAdapters Adapter list to activate.
  /// @param newAllocationBps Adapter allocation list in basis points.
  /// @param action Router action to execute after allocation refresh.
  function _executeStrategy(address[] memory newAdapters, uint256[] memory newAllocationBps, uint8 action) internal {
    uint256 adaptersLength = newAdapters.length;

    if (adaptersLength == 0 || adaptersLength != newAllocationBps.length) {
      revert VaultImplementation__InvalidStrategyAllocation();
    }

    _clearActiveAdapters();

    uint256 totalBps;

    for (uint256 i = 0; i < adaptersLength; i++) {
      address adapter = newAdapters[i];
      uint256 allocationBps = newAllocationBps[i];

      if (adapter == address(0) || allocationBps == 0 || allocationBps > MAX_BPS) {
        continue;
      }

      if (_vaultActiveAdapters.contains(adapter)) {
        continue;
      }

      totalBps += allocationBps;

      if (totalBps > MAX_BPS) {
        revert VaultImplementation__InvalidPercentage();
      }

      _vaultActiveAdapters.add(adapter);

      listAdapters[adapter] =
        AdapterAllocation({allocationBps: uint16(allocationBps), status: AdapterStatus.Active});

      _grantRole(STRATEGY_EXECUTOR_ROLE, adapter);
    }

    emit StrategyExecutionRequest(msg.sender, newAdapters, newAllocationBps);

    uint256 idleAssets = IERC20(asset()).balanceOf(address(this));
    uint256[] memory amountsToInvest = new uint256[](adaptersLength);

    for (uint256 i = 0; i < adaptersLength; i++) {
      amountsToInvest[i] = (idleAssets * newAllocationBps[i]) / MAX_BPS;
    }

    IStrategyRouter(router).executeMultiple(address(this), asset(), newAdapters, amountsToInvest, action);
  }

  /// @dev Reinvests current idle assets according to active adapter allocation.
  function _rebalanceStrategies() internal {
    uint256 length = _vaultActiveAdapters.length();

    if (length == 0) return;

    uint256 idleAssets = IERC20(asset()).balanceOf(address(this));

    if (idleAssets == 0) return;

    address[] memory adapters = _vaultActiveAdapters.values();
    uint256[] memory allocationBps = _getAllocationBps();

    uint256[] memory amountsToInvest = new uint256[](length);

    for (uint256 i = 0; i < length; i++) {
      amountsToInvest[i] = (idleAssets * allocationBps[i]) / MAX_BPS;
    }

    IStrategyRouter(router).executeMultiple(address(this), asset(), adapters, amountsToInvest, INVEST_ACTION);
  }

  /// @dev Requests full divest for all currently active adapters.
  function _divestStrategy() internal {
    uint256 length = _vaultActiveAdapters.length();

    if (length == 0) return;

    address[] memory adapters = _vaultActiveAdapters.values();
    uint256[] memory amountsToDivest = new uint256[](length);

    for (uint256 i = 0; i < length; i++) {
      amountsToDivest[i] = IStrategyAdapter(adapters[i]).totalAssets(address(this), asset());
    }

    IStrategyRouter(router).divestMultiple(address(this), adapters, amountsToDivest);
  }

  /// @dev Clears active adapter set and marks previous adapters as retired.
  function _clearActiveAdapters() internal {
    uint256 length = _vaultActiveAdapters.length();

    if (length == 0) return;

    address[] memory adapters = _vaultActiveAdapters.values();

    for (uint256 i = 0; i < length; i++) {
      address adapter = adapters[i];

      listAdapters[adapter].status = AdapterStatus.Retired;
      listAdapters[adapter].allocationBps = 0;

      _vaultActiveAdapters.remove(adapter);
    }
  }

  /// @dev Collects allocation bps for active adapters preserving set ordering.
  /// @return allocations Basis-point allocations aligned with `_vaultActiveAdapters.values()`.
  function _getAllocationBps() internal view returns (uint256[] memory allocations) {
    uint256 length = _vaultActiveAdapters.length();
    allocations = new uint256[](length);

    for (uint256 i = 0; i < length; i++) {
      address adapter = _vaultActiveAdapters.at(i);
      allocations[i] = listAdapters[adapter].allocationBps;
    }
  }

  /// @dev Bubbles revert data from external call or throws a generic vault external-call error.
  /// @param returndata Raw revert payload from failed low-level call.
  function _revertWithReturnData(bytes memory returndata) internal pure {
    if (returndata.length == 0) {
      revert VaultImplementation__ExternalCallFailed();
    }

    assembly {
      revert(add(returndata, 32), mload(returndata))
    }
  }
}
