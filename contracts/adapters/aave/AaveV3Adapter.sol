// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                           IMPORTS
// =============================================================
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IStrategyAdapter} from "../../interfaces/adapters/IStrategyAdapter.sol";
import {IVaultStrategyExecutor} from "../../interfaces/vaults/IVaultStrategyExecutor.sol";
import {IAaveV3Pool} from "./interfaces/IAaveV3Pool.sol";
import {CommonErrors} from "../../libraries/errors/CommonErrors.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title AaveV3Adapter
/// @notice Executes vault invest/divest operations against an Aave V3 compatible pool.
/// @dev Callable only by the StrategyRouter to keep execution flow centralized.
contract AaveV3Adapter is IStrategyAdapter {
  /*//////////////////////////////////////////////////////////////
                              TYPE DECLARATIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Adapter action enum used by `execute`.
  enum Action {
    Deposit,
    Withdraw
  }

  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @notice Aave V3 pool used for supply and withdraw operations.
  IAaveV3Pool private immutable pool;

  /// @notice Router authorized to invoke adapter execution.
  address public immutable router;

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted after a deposit or withdrawal action is executed for a vault.
  event Executed(address indexed vault, address indexed asset, uint8 indexed action, uint256 amount);

  /*//////////////////////////////////////////////////////////////
                                  ERRORS
  //////////////////////////////////////////////////////////////*/
  /// @notice Thrown when caller is not the configured router.
  error AaveV3Adapter__NotRouter();

  /// @notice Thrown when action value is outside the supported range.
  error AaveV3Adapter__InvalidAction();

  /*//////////////////////////////////////////////////////////////
                              MODIFIERS
  //////////////////////////////////////////////////////////////*/
  /// @dev Restricts execution entrypoint to configured router.
  modifier onlyRouter() {
    if (msg.sender != router) revert AaveV3Adapter__NotRouter();
    _;
  }

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /// @notice Creates adapter with immutable router and Aave pool dependencies.
  /// @param router_ Authorized strategy router.
  /// @param pool_ Aave V3 pool address.
  constructor(address router_, address pool_) {
    if (router_ == address(0) || pool_ == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    router = router_;
    pool = IAaveV3Pool(pool_);
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @inheritdoc IStrategyAdapter
  function execute(address vault, uint8 actionRaw, uint256 amount) external override onlyRouter {
    if (vault == address(0)) revert CommonErrors.ZeroAddress();
    if (amount == 0) revert CommonErrors.ZeroAmount();

    if (actionRaw > uint8(Action.Withdraw)) {
      revert AaveV3Adapter__InvalidAction();
    }

    address asset = IERC4626(vault).asset();

    if (actionRaw == uint8(Action.Deposit)) {
      _deposit(vault, asset, amount);
    } else {
      _withdraw(vault, asset, amount);
    }

    emit Executed(vault, asset, actionRaw, amount);
  }

  // ==========================================================
  //                            VIEW
  // ==========================================================

  /// @inheritdoc IStrategyAdapter
  function totalAssets(address vault, address asset) external view override returns (uint256) {
    return IAaveV3Pool(address(pool)).deposits(vault, asset);
  }

  /// @inheritdoc IStrategyAdapter
  function poolAddress() external view override returns (address) {
    return address(pool);
  }

  // ==========================================================
  //                          INTERNAL
  // ==========================================================

  /// @dev Supplies vault assets into Aave on behalf of the vault.
  /// @param vault Vault address.
  /// @param asset Underlying asset.
  /// @param amount Amount to supply.
  function _deposit(address vault, address asset, uint256 amount) internal {
    IVaultStrategyExecutor(vault).approveTokenFromRouter(asset, address(pool), amount);

    IVaultStrategyExecutor(vault)
      .executeFromRouter(address(pool), 0, abi.encodeCall(IAaveV3Pool.supply, (asset, amount, vault, 0)));
  }

  /// @dev Withdraws vault assets from Aave back to the vault.
  /// @param vault Vault address.
  /// @param asset Underlying asset.
  /// @param amount Amount to withdraw.
  function _withdraw(address vault, address asset, uint256 amount) internal {
    IVaultStrategyExecutor(vault)
      .executeFromRouter(address(pool), 0, abi.encodeCall(IAaveV3Pool.withdraw, (asset, amount, vault)));
  }
}
