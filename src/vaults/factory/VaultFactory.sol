// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IGuardianRegistry} from "../../interfaces/guardians/IGuardianRegistry.sol";
import {IVaultRegistry} from "../../interfaces/vaults/IVaultRegistry.sol";
import {IVault} from "../../interfaces/vaults/IVault.sol";
import {IProtocolCore} from "../../interfaces/core/IProtocolCore.sol";

contract VaultFactory is AccessControl {
  address public immutable implementation;
  address public immutable vaultAdmin;
  address public guardianRegistry;
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
  event GuardianRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
  event VaultRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

  error VaultFactory__ZeroAddress();
  error VaultFactory__GuardianNotActive();
  error VaultFactory__VaultAlreadyExists();
  error VaultFactory__AlreadyDeployed();
  error VaultFactory__DeploymentMismatch();
  error VaultFactory__UnsupportedAsset();
  error VaultFactory__VaultCreationPaused();
  error VaultFactory__NotGuardianCaller();

  constructor(
    address admin_,
    address implementation_,
    address guardianRegistry_,
    address vaultRegistry_,
    address router_,
    address core_,
    address vaultAdmin_
  ) {
    if(
      admin_ == address(0) ||
      implementation_ == address(0) ||
      guardianRegistry_ == address(0) ||
      vaultRegistry_ == address(0) ||
      router_ == address(0) ||
      core_ == address(0) ||
      vaultAdmin_ == address(0)
    ) {
      revert VaultFactory__ZeroAddress();
    }

    implementation = implementation_;
    guardianRegistry = guardianRegistry_;
    vaultRegistry = vaultRegistry_;
    router = router_;
    core = core_;
    vaultAdmin = vaultAdmin_;

    _grantRole(DEFAULT_ADMIN_ROLE, admin_);
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
    address guardian,
    address asset,
    string calldata name,
    string calldata symbol
  ) external returns(address vault, bytes32 salt) {
    if (guardian == address(0) || asset == address(0)) {
      revert VaultFactory__ZeroAddress();
    }

    if (msg.sender != guardian)
      revert VaultFactory__NotGuardianCaller();

    if (IProtocolCore(core).vaultCreationPaused())
      revert VaultFactory__VaultCreationPaused();

    if (!IProtocolCore(core).isAssetSupported(asset))
      revert VaultFactory__UnsupportedAsset();

    if (!IGuardianRegistry(guardianRegistry).isActiveGuardian(guardian))
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
      vaultAdmin,
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

  function isDeploy(
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
    if(newRouter == address(0)) revert VaultFactory__ZeroAddress();

    address oldRouter = router;
    router = newRouter;

    emit RouterUpdated(oldRouter, newRouter);
  }

  function setCore(address newCore) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if(newCore == address(0)) revert VaultFactory__ZeroAddress();

    address oldCore = core;
    core = newCore;

    emit CoreUpdated(oldCore, newCore);
  }

  function setGuardianRegistry(address newGuardianRegistry)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    if(newGuardianRegistry == address(0)) revert VaultFactory__ZeroAddress();

    address oldRegistry = guardianRegistry;
    guardianRegistry = newGuardianRegistry;

    emit GuardianRegistryUpdated(oldRegistry, newGuardianRegistry);
  }

  function setVaultRegistry(address newVaultRegistry)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    if(newVaultRegistry == address(0)) revert VaultFactory__ZeroAddress();

    address oldRegistry = vaultRegistry;
    vaultRegistry = newVaultRegistry;

    emit VaultRegistryUpdated(oldRegistry, newVaultRegistry);
  }
}