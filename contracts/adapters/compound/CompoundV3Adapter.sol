// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                           IMPORTS
// =============================================================
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IStrategyAdapter} from "../../interfaces/adapters/IStrategyAdapter.sol";
import {IVaultStrategyExecutor} from "../../interfaces/vaults/IVaultStrategyExecutor.sol";
import {CommonErrors} from "../../libraries/errors/CommonErrors.sol";
import {ICompoundV3Comet} from "./interfaces/ICompoundV3Comet.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title CompoundV3Adapter
/// @notice Executes vault invest/divest operations against Compound V3 Comet.
/// @dev Callable only by the StrategyRouter to keep execution flow centralized.
contract CompoundV3Adapter is IStrategyAdapter {
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
  /// @notice Compound V3 comet used for supply and withdraw operations.
  ICompoundV3Comet private immutable comet;
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
  error CompoundV3Adapter__NotRouter();
  /// @notice Thrown when action value is outside the supported range.
  error CompoundV3Adapter__InvalidAction();

  /*//////////////////////////////////////////////////////////////
                              MODIFIERS
  //////////////////////////////////////////////////////////////*/
  /// @dev Restricts execution entrypoint to configured router.
  modifier onlyRouter() {
    if (msg.sender != router) revert CompoundV3Adapter__NotRouter();
    _;
  }

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /// @notice Creates adapter with immutable router and comet dependencies.
  /// @param router_ Authorized strategy router.
  /// @param comet_ Compound V3 comet address.
  constructor(address router_, address comet_) {
    if (router_ == address(0) || comet_ == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    router = router_;
    comet = ICompoundV3Comet(comet_);
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @inheritdoc IStrategyAdapter
  function execute(address vault, uint8 actionRaw, uint256 amount) external override onlyRouter {
    if (vault == address(0)) revert CommonErrors.ZeroAddress();
    if (amount == 0) revert CommonErrors.ZeroAmount();

    if (actionRaw > uint8(Action.Withdraw)) {
      revert CompoundV3Adapter__InvalidAction();
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
    return ICompoundV3Comet(address(comet)).deposits(vault, asset);
  }

  /// @inheritdoc IStrategyAdapter
  function poolAddress() external view override returns (address) {
    return address(comet);
  }

  // ==========================================================
  //                          INTERNAL
  // ==========================================================

  /// @dev Supplies vault assets into Compound V3.
  /// @param vault Vault address.
  /// @param asset Underlying asset.
  /// @param amount Amount to supply.
  function _deposit(address vault, address asset, uint256 amount) internal {
    IVaultStrategyExecutor(vault).approveTokenFromRouter(asset, address(comet), amount);

    IVaultStrategyExecutor(vault)
      .executeFromRouter(address(comet), 0, abi.encodeCall(ICompoundV3Comet.supply, (asset, amount)));
  }

  /// @dev Withdraws vault assets from Compound V3 back to the vault.
  /// @param vault Vault address.
  /// @param asset Underlying asset.
  /// @param amount Amount to withdraw.
  function _withdraw(address vault, address asset, uint256 amount) internal {
    IVaultStrategyExecutor(vault)
      .executeFromRouter(address(comet), 0, abi.encodeCall(ICompoundV3Comet.withdrawTo, (vault, asset, amount)));
  }
}
