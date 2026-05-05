// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface ICompoundV3Comet {
  function supply(address asset, uint256 amount) external;

  function withdrawTo(address to, address asset, uint256 amount) external;

  function balanceOf(address account) external view returns (uint256);

  function deposits(address user, address asset) external view returns (uint256);
}
