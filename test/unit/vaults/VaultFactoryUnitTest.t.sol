// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {VaultFactory} from "../../../contracts/vaults/factory/VaultFactory.sol";
import {VaultRegistry} from "../../../contracts/vaults/registry/VaultRegistry.sol";
import {MockVaultRegistryForFactory} from "../../mocks/MockVaultRegistryForFactory.sol";
import {VaultImplementation} from "../../../contracts/vaults/implementations/VaultImplementation.sol";
import {ProtocolCore} from "../../../contracts/core/ProtocolCore.sol";
import {MockGuardianStatus} from "../../mocks/MockGuardianStatus.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {CommonErrors} from "../../../contracts/libraries/errors/CommonErrors.sol";

contract VaultFactoryUnitTest is Test {
  VaultFactory internal factory;
  VaultRegistry internal registry;
  ProtocolCore internal core;
  VaultImplementation internal implementation;
  MockGuardianStatus internal guardians;
  MockERC20 internal asset;

  address internal guardian = makeAddr("guardian");

  function setUp() public {
    asset = new MockERC20("Asset", "AST", 18);

    address[] memory allowedGenesisTokens = new address[](1);
    allowedGenesisTokens[0] = address(asset);

    ProtocolCore coreImpl = new ProtocolCore();
    core = ProtocolCore(
      address(
        new ERC1967Proxy(
          address(coreImpl),
          abi.encodeCall(ProtocolCore.initialize, (payable(address(this)), address(this), allowedGenesisTokens, address(asset)))
        )
      )
    );

    registry = new VaultRegistry(address(this));
    implementation = new VaultImplementation();
    guardians = new MockGuardianStatus();

    factory = new VaultFactory(
      address(this), address(implementation), address(guardians), address(registry), makeAddr("router"), address(core)
    );

    registry.setFactory(address(factory));
    guardians.setActive(guardian, true);
  }

  function testConstructorRejectsZeroAddresses() public {
    // Test: constructor revierte si cualquier dependencia crítica es cero.
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    new VaultFactory(address(0), address(implementation), address(guardians), address(registry), makeAddr("router"), address(core));
  }

  function testPredictAndIsDeployedBeforeAndAfterCreate() public {
    // Test: predict/isDeployed reflejan estado antes y después de crear vault.
    (bytes32 salt, address predictedBefore) = factory.predictVaultAddress(guardian, address(asset));
    (address predictedStatus, bool deployedBefore) = factory.isDeployed(guardian, address(asset));

    assertEq(predictedBefore, predictedStatus);
    assertEq(salt, factory.makeSalt(guardian, address(asset)));
    assertFalse(deployedBefore);

    vm.prank(guardian);
    (address vault,) = factory.createVault(address(asset), "Vault", "vAST");

    (address predictedAfter, bool deployedAfter) = factory.isDeployed(guardian, address(asset));
    assertEq(vault, predictedAfter);
    assertTrue(deployedAfter);
  }

  function testAdminSettersValidateZeroAddressAndRole() public {
    // Test: setters son admin-only y validan zero address.
    vm.prank(guardian);
    vm.expectRevert();
    factory.setRouter(makeAddr("newRouter"));

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    factory.setRouter(address(0));
    factory.setRouter(makeAddr("newRouter"));

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    factory.setCore(address(0));

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    factory.setGuardianAdministrator(address(0));

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    factory.setVaultRegistry(address(0));
  }

  function testAlreadyDeployedPathRevertsWhenRegistryReturnsNoExistingVault() public {
    // Test: si la dirección determinística ya tiene código, createVault revierte con AlreadyDeployed.
    vm.prank(guardian);
    factory.createVault(address(asset), "Vault", "vAST");

    MockVaultRegistryForFactory fakeRegistry = new MockVaultRegistryForFactory();
    factory.setVaultRegistry(address(fakeRegistry));

    vm.prank(guardian);
    vm.expectRevert(VaultFactory.VaultFactory__AlreadyDeployed.selector);
    factory.createVault(address(asset), "Vault Again", "vAST2");
  }
}
