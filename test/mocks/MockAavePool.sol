// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockAavePool {
  mapping(address => mapping(address => uint256)) public deposits;
  // user => asset => amount

  event Supplied(address indexed user, address indexed asset, uint256 amount);
  event Withdrawn(address indexed user, address indexed asset, uint256 amount);

  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 /* referralCode */
  )
    external
  {
    require(amount > 0, "amount = 0");

    IERC20(asset).transferFrom(msg.sender, address(this), amount);

    deposits[onBehalfOf][asset] += amount;

    emit Supplied(onBehalfOf, asset, amount);
  }

  function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
    uint256 userBalance = deposits[msg.sender][asset];
    require(userBalance >= amount, "insufficient balance");

    deposits[msg.sender][asset] -= amount;

    IERC20(asset).transfer(to, amount);

    emit Withdrawn(msg.sender, asset, amount);

    return amount;
  }

  function getUserAccountData(
    address /* user */
  )
    external
    pure
    returns (
      uint256 totalCollateralBase,
      uint256 totalDebtBase,
      uint256 availableBorrowsBase,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    )
  {
    // mock simple → sin lógica real
    return (0, 0, 0, 0, 0, 1e18);
  }
}
