// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IVaultRegistry} from "../../contracts/interfaces/vaults/IVaultRegistry.sol";

contract MockVaultRegistryForFactory is IVaultRegistry {
  address public forcedVault;
  bool public active = true;

  function setForcedVault(address vault) external {
    forcedVault = vault;
  }

  function setActive(bool value) external {
    active = value;
  }

  function registerVault(address, address, address) external override {}

  function getVaultByAssetAndGuardian(address, address) external view override returns (address) {
    return forcedVault;
  }

  function isActiveVault(address) external view override returns (bool) {
    return active;
  }
}
