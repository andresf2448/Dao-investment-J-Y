// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";

contract ProtocolCore is
  Initializable,
  AccessControlUpgradeable,
  UUPSUpgradeable
{
  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

  mapping(address => bool) private _supportedAssets;

  bool public vaultCreationPaused;
  bool public depositsPaused;

  event SupportedAssetSet(address indexed asset, bool allowed);
  event VaultCreationPauseSet(bool paused);
  event DepositsPauseSet(bool paused);

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address adminTimelock,
    address emergencyOperator
  ) external initializer {
    if(adminTimelock == address(0) || emergencyOperator == address(0))
      revert CommonErrors.ZeroAddress();

    __AccessControl_init();

    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock);
    _grantRole(MANAGER_ROLE, adminTimelock);
    _grantRole(EMERGENCY_ROLE, emergencyOperator);
  }

  function setSupportedAsset(
    address asset,
    bool allowed
  ) external onlyRole(MANAGER_ROLE) {
    if (asset == address(0)) revert CommonErrors.ZeroAddress();
    _supportedAssets[asset] = allowed;
    emit SupportedAssetSet(asset, allowed);
  }

  function isAssetSupported(address asset) external view returns(bool) {
    return _supportedAssets[asset];
  }

  function pauseVaultCreation() external onlyRole(EMERGENCY_ROLE) {
    vaultCreationPaused = true;
    emit VaultCreationPauseSet(true);
  }

  function pauseDeposits() external onlyRole(EMERGENCY_ROLE) {
    depositsPaused = true;
    emit DepositsPauseSet(true);
  }

  function unpauseVaultCreation() external onlyRole(MANAGER_ROLE) {
    vaultCreationPaused = false;
    emit VaultCreationPauseSet(false);
  }

  function unpauseDeposits() external onlyRole(MANAGER_ROLE) {
    depositsPaused = false;
    emit DepositsPauseSet(false);
  }

  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}