// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IVaultStrategyExecutor} from "../../contracts/interfaces/vaults/IVaultStrategyExecutor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockVaultExecutor4626 is IVaultStrategyExecutor {
  using SafeERC20 for IERC20;

  address public immutable assetToken;

  constructor(address assetToken_) {
    assetToken = assetToken_;
  }

  function asset() external view returns (address) {
    return assetToken;
  }

  function executeFromRouter(address target, uint256 value, bytes calldata data)
    external
    override
    returns (bytes memory result)
  {
    (bool success, bytes memory ret) = target.call{value: value}(data);
    require(success, "router call failed");
    return ret;
  }

  function approveTokenFromRouter(address token, address spender, uint256 amount) external override {
    IERC20(token).forceApprove(spender, amount);
  }

  receive() external payable {}
}
