// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IProtocolCore {
  function isVaultAssetSupported(address asset) external view returns (bool);
  function isVaultCreationPaused() external view returns (bool);
  function isDepositsPaused() external view returns (bool);
  function hasGenesisToken(address token) external view returns(bool);
}