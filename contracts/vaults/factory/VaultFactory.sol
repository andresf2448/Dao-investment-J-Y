// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                           IMPORTS
// =============================================================
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IGuardianAdministrator} from "../../interfaces/guardians/IGuardianAdministrator.sol";
import {IVaultRegistry} from "../../interfaces/vaults/IVaultRegistry.sol";
import {IVault} from "../../interfaces/vaults/IVault.sol";
import {IProtocolCore} from "../../interfaces/core/IProtocolCore.sol";
import {CommonErrors} from "../../libraries/errors/CommonErrors.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title VaultFactory
/// @notice Deterministically deploys guardian vault clones and registers them in the protocol.
/// @dev Enforces guardian eligibility and protocol pause/support rules before clone creation.
contract VaultFactory is AccessControl {
  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @notice Timelock admin used during vault initialization.
  address public immutable adminTimelock;

  /// @notice Vault implementation address used for clone deployment.
  address public immutable implementation;

  /// @notice Guardian administrator used to verify guardian activity.
  address public guardianAdministrator;

  /// @notice Registry that stores vault canonical records.
  address public vaultRegistry;

  /// @notice Router assigned to newly created vaults.
  address public router;

  /// @notice Core contract consulted for pauses and asset support.
  address public core;

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when a new vault clone is created and registered.
  event VaultCreated(
    address indexed guardian, address indexed asset, address indexed vault, bytes32 salt, string name, string symbol
  );

  /// @notice Emitted when router dependency is updated.
  event RouterUpdated(address indexed oldRouter, address indexed newRouter);

  /// @notice Emitted when core dependency is updated.
  event CoreUpdated(address indexed oldCore, address indexed newCore);

  /// @notice Emitted when guardian administrator dependency is updated.
  event GuardianAdministratorUpdated(address indexed oldAdministrator, address indexed newAdministrator);

  /// @notice Emitted when vault registry dependency is updated.
  event VaultRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

  /*//////////////////////////////////////////////////////////////
                                  ERRORS
  //////////////////////////////////////////////////////////////*/
  /// @notice Thrown when caller is not an active guardian.
  error VaultFactory__GuardianNotActive();

  /// @notice Thrown when guardian already has a vault for the same asset.
  error VaultFactory__VaultAlreadyExists();

  /// @notice Thrown when deterministic target address already contains code.
  error VaultFactory__AlreadyDeployed();

  /// @notice Thrown when deployed address differs from deterministic prediction.
  error VaultFactory__DeploymentMismatch();

  /// @notice Thrown when requested asset is not enabled for vault creation.
  error VaultFactory__UnsupportedAsset();

  /// @notice Thrown when vault creation is globally paused in core.
  error VaultFactory__VaultCreationPaused();

  /// @notice Thrown when a guardian-only action is called by a non-guardian.
  error VaultFactory__NotGuardianCaller();

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /// @notice Initializes factory dependencies for deterministic vault deployment.
  /// @param adminTimelock_ Timelock admin assigned to new vaults.
  /// @param implementation_ Vault implementation used for clone creation.
  /// @param guardianAdministrator_ Guardian administrator for activity checks.
  /// @param vaultRegistry_ Registry where new vaults are recorded.
  /// @param router_ Router assigned to new vaults.
  /// @param core_ Core contract used for pause and asset-support checks.
  constructor(
    address adminTimelock_,
    address implementation_,
    address guardianAdministrator_,
    address vaultRegistry_,
    address router_,
    address core_
  ) {
    if (
      adminTimelock_ == address(0) || implementation_ == address(0) || guardianAdministrator_ == address(0)
        || vaultRegistry_ == address(0) || router_ == address(0) || core_ == address(0)
    ) {
      revert CommonErrors.ZeroAddress();
    }

    implementation = implementation_;
    guardianAdministrator = guardianAdministrator_;
    vaultRegistry = vaultRegistry_;
    router = router_;
    core = core_;
    adminTimelock = adminTimelock_;

    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock_);
  }

  // ==========================================================
  //                           PUBLIC
  // ==========================================================

  /// @notice Computes deterministic salt used for vault clone deployment.
  /// @param guardian Guardian address.
  /// @param asset Vault underlying asset.
  /// @return result Salt used with cloneDeterministic.
  function makeSalt(address guardian, address asset) public pure returns (bytes32 result) {
    // more gas-efficient equivalent to keccak256(abi.encode(guardian, asset))
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, guardian)
      mstore(add(ptr, 32), asset)
      result := keccak256(ptr, 64)
    }
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @notice Predicts vault address for a guardian/asset pair.
  /// @param guardian Guardian address.
  /// @param asset Vault underlying asset.
  /// @return salt Deterministic deployment salt.
  /// @return predicted Predicted clone address.
  function predictVaultAddress(address guardian, address asset)
    external
    view
    returns (bytes32 salt, address predicted)
  {
    salt = makeSalt(guardian, asset);
    predicted = Clones.predictDeterministicAddress(implementation, salt, address(this));
  }

  /// @notice Creates and registers a new vault clone for caller guardian and provided asset.
  /// @param asset Underlying asset for the vault.
  /// @param name Share token name.
  /// @param symbol Share token symbol.
  /// @return vault Deployed vault clone address.
  /// @return salt Deterministic deployment salt used.
  function createVault(address asset, string calldata name, string calldata symbol)
    external
    returns (address vault, bytes32 salt)
  {
    address guardian = msg.sender;

    if (guardian == address(0) || asset == address(0)) {
      revert CommonErrors.ZeroAddress();
    }
    if (IProtocolCore(core).isVaultCreationPaused()) {
      revert VaultFactory__VaultCreationPaused();
    }
    if (!IProtocolCore(core).isVaultAssetSupported(asset)) {
      revert VaultFactory__UnsupportedAsset();
    }
    if (!IGuardianAdministrator(guardianAdministrator).isActiveGuardian(guardian)) {
      revert VaultFactory__GuardianNotActive();
    }

    address existingVault = IVaultRegistry(vaultRegistry).getVaultByAssetAndGuardian(asset, guardian);

    if (existingVault != address(0)) {
      revert VaultFactory__VaultAlreadyExists();
    }

    salt = makeSalt(guardian, asset);

    address predicted = Clones.predictDeterministicAddress(implementation, salt, address(this));

    if (predicted.code.length != 0) {
      revert VaultFactory__AlreadyDeployed();
    }

    vault = Clones.cloneDeterministic(implementation, salt);

    if (vault != predicted) {
      revert VaultFactory__DeploymentMismatch();
    }

    IVault(vault).initialize(asset, name, symbol, guardian, adminTimelock, address(this), router, core);

    IVaultRegistry(vaultRegistry).registerVault(vault, guardian, asset);

    emit VaultCreated(guardian, asset, vault, salt, name, symbol);
  }

  /// @notice Checks deterministic deployment status for guardian/asset vault pair.
  /// @param guardian Guardian address.
  /// @param asset Vault underlying asset.
  /// @return predicted Predicted clone address.
  /// @return deployed True if code already exists at predicted address.
  function isDeployed(address guardian, address asset) external view returns (address predicted, bool deployed) {
    bytes32 salt = makeSalt(guardian, asset);
    predicted = Clones.predictDeterministicAddress(implementation, salt, address(this));
    deployed = predicted.code.length > 0;
  }

  /// @notice Updates router used by newly initialized vaults.
  /// @param newRouter New router address.
  function setRouter(address newRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (newRouter == address(0)) revert CommonErrors.ZeroAddress();

    address oldRouter = router;
    router = newRouter;

    emit RouterUpdated(oldRouter, newRouter);
  }

  /// @notice Updates core dependency used by newly initialized vaults.
  /// @param newCore New core address.
  function setCore(address newCore) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (newCore == address(0)) revert CommonErrors.ZeroAddress();

    address oldCore = core;
    core = newCore;

    emit CoreUpdated(oldCore, newCore);
  }

  /// @notice Updates guardian administrator dependency.
  /// @param newGuardianAdministrator New guardian administrator address.
  function setGuardianAdministrator(address newGuardianAdministrator) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (newGuardianAdministrator == address(0)) revert CommonErrors.ZeroAddress();

    address oldAdministrator = guardianAdministrator;
    guardianAdministrator = newGuardianAdministrator;

    emit GuardianAdministratorUpdated(oldAdministrator, newGuardianAdministrator);
  }

  /// @notice Updates vault registry dependency.
  /// @param newVaultRegistry New registry address.
  function setVaultRegistry(address newVaultRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (newVaultRegistry == address(0)) revert CommonErrors.ZeroAddress();

    address oldRegistry = vaultRegistry;
    vaultRegistry = newVaultRegistry;

    emit VaultRegistryUpdated(oldRegistry, newVaultRegistry);
  }
}
