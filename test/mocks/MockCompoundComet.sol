// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockCompoundComet {
  using SafeERC20 for IERC20;

  mapping(address => mapping(address => uint256)) public deposits;
  // user => asset => amount

  event Supplied(address indexed account, address indexed asset, uint256 amount);
  event Withdrawn(address indexed account, address indexed to, address indexed asset, uint256 amount);

  function supply(address asset, uint256 amount) external {
    require(amount > 0, "amount = 0");

    IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    deposits[msg.sender][asset] += amount;

    emit Supplied(msg.sender, asset, amount);
  }

  function withdrawTo(address to, address asset, uint256 amount) external {
    require(to != address(0), "to = 0");

    uint256 balance = deposits[msg.sender][asset];
    require(balance >= amount, "insufficient balance");

    deposits[msg.sender][asset] = balance - amount;
    IERC20(asset).safeTransfer(to, amount);

    emit Withdrawn(msg.sender, to, asset, amount);
  }

  function balanceOf(
    address /* account */
  )
    external
    pure
    returns (uint256)
  {
    return 0;
  }
}
