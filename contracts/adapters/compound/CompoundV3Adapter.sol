// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IStrategyAdapter} from "../../interfaces/adapters/IStrategyAdapter.sol";
import {IVaultStrategyExecutor} from "../../interfaces/vaults/IVaultStrategyExecutor.sol";
import {CommonErrors} from "../../libraries/errors/CommonErrors.sol";
import {ICompoundV3Comet} from "./interfaces/ICompoundV3Comet.sol";

contract CompoundV3Adapter is IStrategyAdapter {
  enum Action {
    Deposit,
    Withdraw
  }

  ICompoundV3Comet private immutable comet;
  address public immutable router;

  event Executed(
    address indexed vault,
    address indexed asset,
    uint8 indexed action,
    uint256 amount
  );

  error CompoundV3Adapter__NotRouter();
  error CompoundV3Adapter__InvalidAction();

  modifier onlyRouter() {
    if (msg.sender != router) revert CompoundV3Adapter__NotRouter();
    _;
  }

  constructor(address router_, address comet_) {
    if (router_ == address(0) || comet_ == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    router = router_;
    comet = ICompoundV3Comet(comet_);
  }

  function execute(
    address vault,
    uint8 actionRaw,
    uint256 amount
  ) external override onlyRouter {
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

  function totalAssets(
    address vault,
    address asset
  ) external view override returns (uint256) {
    return ICompoundV3Comet(address(comet)).deposits(vault, asset);
  }

  function poolAddress() external view override returns (address) {
    return address(comet);
  }

  function _deposit(
    address vault,
    address asset,
    uint256 amount
  ) internal {
    IVaultStrategyExecutor(vault).approveTokenFromRouter(
      asset,
      address(comet),
      amount
    );

    IVaultStrategyExecutor(vault).executeFromRouter(
      address(comet),
      0,
      abi.encodeCall(
        ICompoundV3Comet.supply,
        (asset, amount)
      )
    );
  }

  function _withdraw(
    address vault,
    address asset,
    uint256 amount
  ) internal {
    IVaultStrategyExecutor(vault).executeFromRouter(
      address(comet),
      0,
      abi.encodeCall(
        ICompoundV3Comet.withdrawTo,
        (vault, asset, amount)
      )
    );
  }
}
