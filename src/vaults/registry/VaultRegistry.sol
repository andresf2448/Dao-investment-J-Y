// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract VaultRegistry is AccessControl {
  struct VaultDetail {
    address guardian;
    address asset;
    uint48 registeredAt;
    bool active;
  }

  bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

  mapping(address asset => address[] vaults) private vaultsByAsset;
  mapping(address guardian => address[] vaults) private vaultsByGuardian;
  mapping(address asset => mapping(address guardian => address vault)) private vaultByAssetGuardian;
  mapping(address vault => VaultDetail) private vaultDetails;
  mapping(address vault => bool) public isRegistered;
  address[] private allVaults;

  event VaultRegistered(
    address indexed vault,
    address indexed guardian,
    address indexed asset,
    uint256 registeredAt
  );

  event VaultDeactivated(
    address indexed vault,
    uint256 deactivatedAt
  );

  error VaultRegistry__InvalidVaultAddress();
  error VaultRegistry__InvalidGuardianAddress();
  error VaultRegistry__InvalidAssetAddress();
  error VaultRegistry__InvalidAdminAddress();
  error VaultRegistry__InvalidFactoryAddress();
  error VaultRegistry__AlreadyRegistered();
  error VaultRegistry__PairAlreadyExists();
  error VaultRegistry__VaultNotRegistered();
  error VaultRegistry__VaultAlreadyInactive();
  error VaultRegistry__NotVaultGuardian();

  constructor(address admin, address factory) {
    if(admin == address(0)) revert VaultRegistry__InvalidAdminAddress();
    if(factory == address(0)) revert VaultRegistry__InvalidFactoryAddress();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(FACTORY_ROLE, factory);
  }

  function registerVault(
    address vault,
    address guardian,
    address asset
  )
    external
    onlyRole(FACTORY_ROLE)
  {
    if (vault == address(0)) revert VaultRegistry__InvalidVaultAddress();
    if (guardian == address(0)) revert VaultRegistry__InvalidGuardianAddress();
    if (asset == address(0)) revert VaultRegistry__InvalidAssetAddress();
    if (isRegistered[vault]) revert VaultRegistry__AlreadyRegistered();
    if (vaultByAssetGuardian[asset][guardian] != address(0))
      revert VaultRegistry__PairAlreadyExists();

    isRegistered[vault] = true;
    vaultsByAsset[asset].push(vault);
    vaultsByGuardian[guardian].push(vault);
    vaultByAssetGuardian[asset][guardian] = vault;
    allVaults.push(vault);

    vaultDetails[vault] = VaultDetail({
      guardian: guardian,
      asset: asset,
      registeredAt: uint48(block.timestamp),
      active: true
    });

    emit VaultRegistered(vault, guardian, asset, block.timestamp);
  }

  function deactivateVault(address vault) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (!isRegistered[vault]) revert VaultRegistry__VaultNotRegistered();
    if (!vaultDetails[vault].active) revert VaultRegistry__VaultAlreadyInactive();

    vaultDetails[vault].active = false;

    emit VaultDeactivated(vault, block.timestamp);
  }

  function deactivateOwnVault(address vault) external {
    if (!isRegistered[vault]) revert VaultRegistry__VaultNotRegistered();
    if (vaultDetails[vault].guardian != msg.sender) revert VaultRegistry__NotVaultGuardian();
    if (!vaultDetails[vault].active) revert VaultRegistry__VaultAlreadyInactive();

    vaultDetails[vault].active = false;

    emit VaultDeactivated(vault, block.timestamp);
  }

  function getVaultDetail(address vault)
    external
    view
    returns(VaultDetail memory)
  {
    if(!isRegistered[vault]) revert VaultRegistry__VaultNotRegistered();
    return vaultDetails[vault];
  }

  function getVaultByAssetAndGuardian(
    address asset,
    address guardian
  ) external view returns(address) {
    return vaultByAssetGuardian[asset][guardian];
  }

  function isActiveVault(address vault)
    external
    view
    returns(bool)
  {
    if(!isRegistered[vault]) return false;
    return vaultDetails[vault].active;
  }

  function getVaultsByAsset(address asset)
    external
    view
    returns(address[] memory)
  {
    return vaultsByAsset[asset];
  }

  function getVaultsByGuardian(address guardian)
    external
    view
    returns(address[] memory)
  {
    return vaultsByGuardian[guardian];
  }

  function getAllVaults()
    external
    view returns(address[] memory)
  {
    return allVaults;
  }

  function totalVaults()
    external
    view
    returns(uint256)
  {
    return allVaults.length;
  }

  function totalVaultsByAsset(address asset)
    external
    view
    returns(uint256)
  {
    return vaultsByAsset[asset].length;
  }

  function totalVaultsByGuardian(address guardian)
    external
    view
    returns(uint256)
  {
    return vaultsByGuardian[guardian].length;
  }
}