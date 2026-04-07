// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IProtocolCore {
  function isAssetSupported(address asset) external view returns (bool);
  function vaultCreationPaused() external view returns (bool);
  function depositsPaused() external view returns (bool);
}