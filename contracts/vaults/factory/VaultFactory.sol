// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IGuardianAdministrator} from "../../interfaces/guardians/IGuardianAdministrator.sol";
import {IVaultRegistry} from "../../interfaces/vaults/IVaultRegistry.sol";
import {IVault} from "../../interfaces/vaults/IVault.sol";
import {IProtocolCore} from "../../interfaces/core/IProtocolCore.sol";
import {CommonErrors} from "../../libraries/errors/CommonErrors.sol";

contract VaultFactory is AccessControl {
  address public immutable adminTimelock;
  address public immutable implementation;
  address public guardianAdministrator;
  address public vaultRegistry;
  address public router;
  address public core;

  event VaultCreated(
    address indexed guardian,
    address indexed asset,
    address indexed vault,
    bytes32 salt,
    string name,
    string symbol
  );

  event RouterUpdated(address indexed oldRouter, address indexed newRouter);
  event CoreUpdated(address indexed oldCore, address indexed newCore);
  event GuardianAdministratorUpdated(address indexed oldAdministrator, address indexed newAdministrator);
  event VaultRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

  error VaultFactory__GuardianNotActive();
  error VaultFactory__VaultAlreadyExists();
  error VaultFactory__AlreadyDeployed();
  error VaultFactory__DeploymentMismatch();
  error VaultFactory__UnsupportedAsset();
  error VaultFactory__VaultCreationPaused();
  error VaultFactory__NotGuardianCaller();

  constructor(
    address adminTimelock_, //tiemlock
    address implementation_, //molde
    address guardianAdministrator_,//direccion donde va a buscar los guardianes activos
    address vaultRegistry_, //donde se guarda el vault creado registro
    address router_, //setea el router para luego hacer las inversiones
    address core_ // direccion del core para consultar assets soportados y si la creacion de vaults esta pausada
  ) {
    if(
      adminTimelock_ == address(0) ||
      implementation_ == address(0) ||
      guardianAdministrator_ == address(0) ||
      vaultRegistry_ == address(0) ||
      router_ == address(0) ||
      core_ == address(0)
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

  function makeSalt(address guardian, address asset)
    public
    pure
    returns(bytes32 result)
  {
    // option1 less gas efficient, option2 more gas efficient but requires inline assembly. Both return the same result.
    // return keccak256(abi.encode(guardian, asset));

    // option2 inline assembly
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, guardian)
      mstore(add(ptr, 32), asset)
      result := keccak256(ptr, 64)
    }
  }

  function predictVaultAddress(address guardian, address asset)
    external
    view
    returns(bytes32 salt, address predicted)
  {
    salt = makeSalt(guardian, asset);
    predicted = Clones.predictDeterministicAddress(
      implementation,
      salt,
      address(this)
    );
  }

  function createVault(
    address asset,
    string calldata name,
    string calldata symbol
  ) external returns(address vault, bytes32 salt) {
    address guardian = msg.sender;

    if (guardian == address(0) || asset == address(0))
      revert CommonErrors.ZeroAddress();
    if (IProtocolCore(core).isVaultCreationPaused())
      revert VaultFactory__VaultCreationPaused();
    if (!IProtocolCore(core).isVaultAssetSupported(asset))
      revert VaultFactory__UnsupportedAsset();
    if (!IGuardianAdministrator(guardianAdministrator).isActiveGuardian(guardian))
      revert VaultFactory__GuardianNotActive();

    address existingVault = IVaultRegistry(vaultRegistry)
      .getVaultByAssetAndGuardian(asset, guardian);

    if (existingVault != address(0))
      revert VaultFactory__VaultAlreadyExists();

    salt = makeSalt(guardian, asset);

    address predicted = Clones.predictDeterministicAddress(
      implementation,
      salt,
      address(this)
    );

    if (predicted.code.length != 0) {
      revert VaultFactory__AlreadyDeployed();
    }

    vault = Clones.cloneDeterministic(implementation, salt);

    if (vault != predicted) {
      revert VaultFactory__DeploymentMismatch();
    }

    IVault(vault).initialize(
      asset,
      name,
      symbol,
      guardian,
      adminTimelock,
      address(this),
      router,
      core
    );

    IVaultRegistry(vaultRegistry).registerVault(vault, guardian, asset);

    emit VaultCreated(
      guardian,
      asset,
      vault,
      salt,
      name,
      symbol
    );
  }

  function isDeployed(
    address guardian,
    address asset
  )
    external
    view
    returns(address predicted, bool deployed) 
  {
    bytes32 salt = makeSalt(guardian, asset);
    predicted = Clones.predictDeterministicAddress(implementation, salt, address(this));
    deployed = predicted.code.length > 0;
  }

  function setRouter(address newRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if(newRouter == address(0)) revert CommonErrors.ZeroAddress();

    address oldRouter = router;
    router = newRouter;

    emit RouterUpdated(oldRouter, newRouter);
  }

  function setCore(address newCore) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if(newCore == address(0)) revert CommonErrors.ZeroAddress();

    address oldCore = core;
    core = newCore;

    emit CoreUpdated(oldCore, newCore);
  }

  function setGuardianAdministrator(address newGuardianAdministrator)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    if(newGuardianAdministrator == address(0)) revert CommonErrors.ZeroAddress();

    address oldAdministrator = guardianAdministrator;
    guardianAdministrator = newGuardianAdministrator;

    emit GuardianAdministratorUpdated(oldAdministrator, newGuardianAdministrator);
  }

  function setVaultRegistry(address newVaultRegistry)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    if(newVaultRegistry == address(0)) revert CommonErrors.ZeroAddress();

    address oldRegistry = vaultRegistry;
    vaultRegistry = newVaultRegistry;

    emit VaultRegistryUpdated(oldRegistry, newVaultRegistry);
  }
}