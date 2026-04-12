// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IStrategyAdapter} from "../../interfaces/adapters/IStrategyAdapter.sol";
import {IVaultStrategyExecutor} from "../../interfaces/vaults/IVaultStrategyExecutor.sol";
import {IAaveV3Pool} from "./interfaces/IAaveV3Pool.sol";
import {CommonErrors} from "../../libraries/errors/CommonErrors.sol";

contract AaveV3Adapter is IStrategyAdapter {
  enum Action {
    Deposit,
    Withdraw
  }

  IAaveV3Pool public immutable pool;
  address public immutable router;

  event Executed(
    address indexed vault,
    address indexed asset,
    uint8 indexed action,
    uint256 amount
  );

  error AaveV3Adapter__NotRouter();
  error AaveV3Adapter__InvalidAction();

  modifier onlyRouter() {
    if(msg.sender != router) revert AaveV3Adapter__NotRouter();
    _;
  }

  constructor(address router_, address pool_) {
    if(router_ == address(0) || pool_ == address(0))
      revert CommonErrors.ZeroAddress();
    
    router = router_;
    pool = IAaveV3Pool(pool_);
  }

  function execute(address vault, bytes calldata data)
    external
    override
    onlyRouter
  {
    address asset = IERC4626(vault).asset();

    (uint8 actionRaw, uint256 amount) = abi.decode(data, (uint8, uint256));

    if(amount == 0) revert CommonErrors.ZeroAmount();
    if(actionRaw > uint8(Action.Withdraw))
      revert AaveV3Adapter__InvalidAction();

    Action action = Action(actionRaw);

    if(action == Action.Deposit) {
      _deposit(vault, asset, amount);
    } else {
      _withdraw(vault, asset, amount);
    }

    emit Executed(vault, asset, actionRaw, amount);
  }

  function _deposit(
    address vault,
    address asset,
    uint256 amount
  ) internal {
    IVaultStrategyExecutor(vault).approveTokenFromRouter(asset, address(pool), amount);

    IVaultStrategyExecutor(vault).executeFromRouter(
      address(pool),
      0,
      abi.encodeCall(
        IAaveV3Pool.supply,
        (asset, amount, vault, 0)
      )
    );
  }

  function _withdraw(
    address vault,
    address asset,
    uint256 amount
  ) internal {
    IVaultStrategyExecutor(vault).executeFromRouter(
      address(pool),
      0,
      abi.encodeCall(
        IAaveV3Pool.withdraw,
        (asset, amount, vault)
      )
    );
  }
}