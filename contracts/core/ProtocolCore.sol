// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ProtocolCore is
  Initializable,
  AccessControlUpgradeable,
  UUPSUpgradeable
{
  using EnumerableSet for EnumerableSet.AddressSet;

  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
  mapping(address => bool) private _supportedAssets;
  EnumerableSet.AddressSet private _supportedGenesisTokens;
  bool public isVaultCreationPaused;
  bool public isDepositsPaused;

  event SupportedAssetSet(address indexed asset, bool allowed);
  event VaultCreationPauseSet(bool paused);
  event DepositsPauseSet(bool paused);

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address adminTimelock,
    address emergencyOperator,
    address[] memory allowedGenesisTokens
  ) external initializer {
    if(
      adminTimelock == address(0) ||
      emergencyOperator == address(0)
    )
      revert CommonErrors.ZeroAddress();
    __AccessControl_init();

    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock);
    _grantRole(MANAGER_ROLE, adminTimelock);
    _grantRole(EMERGENCY_ROLE, emergencyOperator);

    _setSupportedGenesisTokens(allowedGenesisTokens);
  }

  function setSupportedVaultAsset(
    address asset,
    bool allowed
  ) external onlyRole(MANAGER_ROLE) {
    if (asset == address(0)) revert CommonErrors.ZeroAddress();
    _supportedAssets[asset] = allowed;
    emit SupportedAssetSet(asset, allowed);
  }

  function isVaultAssetSupported(address asset) external view returns(bool) {
    return _supportedAssets[asset];
  }

  function pauseVaultCreation() external onlyRole(EMERGENCY_ROLE) {
    isVaultCreationPaused = true;
    emit VaultCreationPauseSet(true);
  }

  function pauseVaultDeposits() external onlyRole(EMERGENCY_ROLE) {
    isDepositsPaused = true;
    emit DepositsPauseSet(true);
  }

  function unpauseVaultCreation() external onlyRole(MANAGER_ROLE) {
    isVaultCreationPaused = false;
    emit VaultCreationPauseSet(false);
  }

  function unpauseVaultDeposits() external onlyRole(MANAGER_ROLE) {
    isDepositsPaused = false;
    emit DepositsPauseSet(false);
  }

  function hasGenesisToken(address token) external view returns(bool) {
    return _supportedGenesisTokens.contains(token);
  }

  function getSupportedGenesisTokens() external view returns(address[] memory) {
    return _supportedGenesisTokens.values();
  }

  function setSupportedGenesisTokens(address[] memory allowedGenesisTokens) public onlyRole(MANAGER_ROLE) {
    _setSupportedGenesisTokens(allowedGenesisTokens);
  }

  function _setSupportedGenesisTokens(address[] memory allowedGenesisTokens) internal {
    uint256 length = allowedGenesisTokens.length;

    for(uint256 i = 0; i < length; i++) {
      if(allowedGenesisTokens[i] == address(0)) revert CommonErrors.ZeroAddress();
      _supportedGenesisTokens.add(allowedGenesisTokens[i]);
    }
  }

  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}