// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IVaultRegistry {
  function registerVault(address vault, address guardian, address asset) external;
  function getVaultByAssetAndGuardian(address asset, address guardian)
    external
    view
    returns(address); 
}