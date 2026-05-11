// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// =============================================================
//                           IMPORTS
// =============================================================
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {CommonErrors} from "../../libraries/errors/CommonErrors.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title VaultRegistry
/// @notice Stores canonical vault records and query indices by asset and guardian.
/// @dev Factory registers vaults, while admin/guardian can deactivate entries.
contract VaultRegistry is AccessControl {
  /*//////////////////////////////////////////////////////////////
                              TYPE DECLARATIONS
  //////////////////////////////////////////////////////////////*/
  /// @notice Metadata tracked for each registered vault.
  struct VaultDetail {
    /// @notice Guardian assigned to manage strategy for this vault.
    address guardian;
    /// @notice Underlying asset for this vault.
    address asset;
    /// @notice Timestamp when the vault was registered.
    uint48 registeredAt;
    /// @notice Active status used by protocol services.
    bool active;
  }

  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @notice Role allowed to register new vaults.
  bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

  /// @dev Vault list indexed by underlying asset.
  mapping(address asset => address[] vaults) private vaultsByAsset;

  /// @dev Vault list indexed by guardian.
  mapping(address guardian => address[] vaults) private vaultsByGuardian;

  /// @dev Canonical lookup of vault by asset and guardian pair.
  mapping(address asset => mapping(address guardian => address vault)) private vaultByAssetGuardian;

  /// @dev Detailed metadata by vault address.
  mapping(address vault => VaultDetail) private vaultDetails;

  /// @notice Indicates whether a vault has ever been registered.
  mapping(address vault => bool) public isRegistered;

  /// @dev Flat list of all registered vaults.
  address[] private allVaults;

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when a vault is registered.
  event VaultRegistered(address indexed vault, address indexed guardian, address indexed asset, uint256 registeredAt);

  /// @notice Emitted when a vault is deactivated.
  event VaultDeactivated(address indexed vault, uint256 deactivatedAt);

  /*//////////////////////////////////////////////////////////////
                                  ERRORS
  //////////////////////////////////////////////////////////////*/
  /// @notice Thrown when trying to register an already-registered vault.
  error VaultRegistry__AlreadyRegistered();

  /// @notice Thrown when guardian already has a vault for the same asset.
  error VaultRegistry__PairAlreadyExists();

  /// @notice Thrown when queried or updated vault is not registered.
  error VaultRegistry__VaultNotRegistered();

  /// @notice Thrown when attempting to deactivate an already inactive vault.
  error VaultRegistry__VaultAlreadyInactive();

  /// @notice Thrown when non-guardian attempts guardian-owned deactivation.
  error VaultRegistry__NotVaultGuardian();

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /// @notice Creates registry and assigns default admin role.
  /// @param adminTimelock Timelock admin address.
  constructor(address adminTimelock) {
    if (adminTimelock == address(0)) revert CommonErrors.ZeroAddress();

    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock);
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @notice Grants factory role to contract allowed to register vaults.
  /// @param factory Factory contract address.
  function setFactory(address factory) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (factory == address(0)) revert CommonErrors.ZeroAddress();
    grantRole(FACTORY_ROLE, factory);
  }

  /// @notice Registers a newly deployed vault.
  /// @param vault Vault address.
  /// @param guardian Guardian owner for the vault.
  /// @param asset Underlying asset of the vault.
  function registerVault(address vault, address guardian, address asset) external onlyRole(FACTORY_ROLE) {
    if (vault == address(0)) revert CommonErrors.ZeroAddress();
    if (guardian == address(0)) revert CommonErrors.ZeroAddress();
    if (asset == address(0)) revert CommonErrors.ZeroAddress();
    if (isRegistered[vault]) revert VaultRegistry__AlreadyRegistered();
    if (vaultByAssetGuardian[asset][guardian] != address(0)) {
      revert VaultRegistry__PairAlreadyExists();
    }

    isRegistered[vault] = true;
    vaultsByAsset[asset].push(vault);
    vaultsByGuardian[guardian].push(vault);
    vaultByAssetGuardian[asset][guardian] = vault;
    allVaults.push(vault);

    vaultDetails[vault] =
      VaultDetail({guardian: guardian, asset: asset, registeredAt: uint48(block.timestamp), active: true});

    emit VaultRegistered(vault, guardian, asset, block.timestamp);
  }

  /// @notice Deactivates any registered vault via admin action.
  /// @param vault Vault address to deactivate.
  function deactivateVault(address vault) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (!isRegistered[vault]) revert VaultRegistry__VaultNotRegistered();
    if (!vaultDetails[vault].active) revert VaultRegistry__VaultAlreadyInactive();

    vaultDetails[vault].active = false;

    emit VaultDeactivated(vault, block.timestamp);
  }

  /// @notice Lets guardian deactivate their own vault.
  /// @param vault Vault address to deactivate.
  function deactivateOwnVault(address vault) external {
    if (!isRegistered[vault]) revert VaultRegistry__VaultNotRegistered();
    if (vaultDetails[vault].guardian != msg.sender) revert VaultRegistry__NotVaultGuardian();
    if (!vaultDetails[vault].active) revert VaultRegistry__VaultAlreadyInactive();

    vaultDetails[vault].active = false;

    emit VaultDeactivated(vault, block.timestamp);
  }

  /// @notice Returns detail for a registered vault.
  /// @param vault Vault address.
  /// @return Stored vault detail.
  function getVaultDetail(address vault) external view returns (VaultDetail memory) {
    if (!isRegistered[vault]) revert VaultRegistry__VaultNotRegistered();
    return vaultDetails[vault];
  }

  /// @notice Returns vault mapped to a guardian/asset pair.
  /// @param asset Underlying asset.
  /// @param guardian Guardian address.
  /// @return Vault address or zero if not registered.
  function getVaultByAssetAndGuardian(address asset, address guardian) external view returns (address) {
    return vaultByAssetGuardian[asset][guardian];
  }

  /// @notice Returns whether a vault is currently active.
  /// @param vault Vault address.
  /// @return True if vault is registered and active.
  function isActiveVault(address vault) external view returns (bool) {
    if (!isRegistered[vault]) return false;
    return vaultDetails[vault].active;
  }

  /// @notice Returns all vaults registered for an asset.
  /// @param asset Underlying asset.
  /// @return Vault list for the asset.
  function getVaultsByAsset(address asset) external view returns (address[] memory) {
    return vaultsByAsset[asset];
  }

  /// @notice Returns all vaults owned by a guardian.
  /// @param guardian Guardian address.
  /// @return Vault list for the guardian.
  function getVaultsByGuardian(address guardian) external view returns (address[] memory) {
    return vaultsByGuardian[guardian];
  }

  /// @notice Returns every vault ever registered.
  /// @return Full vault list.
  function getAllVaults() external view returns (address[] memory) {
    return allVaults;
  }

  /// @notice Returns total registered vault count.
  /// @return Number of registered vaults.
  function totalVaults() external view returns (uint256) {
    return allVaults.length;
  }

  /// @notice Returns registered vault count for an asset.
  /// @param asset Underlying asset.
  /// @return Count of vaults for asset.
  function totalVaultsByAsset(address asset) external view returns (uint256) {
    return vaultsByAsset[asset].length;
  }

  /// @notice Returns registered vault count for a guardian.
  /// @param guardian Guardian address.
  /// @return Count of vaults for guardian.
  function totalVaultsByGuardian(address guardian) external view returns (uint256) {
    return vaultsByGuardian[guardian].length;
  }
}
