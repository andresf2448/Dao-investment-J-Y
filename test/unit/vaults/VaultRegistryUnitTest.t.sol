// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {VaultRegistry} from "../../../contracts/vaults/registry/VaultRegistry.sol";
import {CommonErrors} from "../../../contracts/libraries/errors/CommonErrors.sol";

contract VaultRegistryUnitTest is Test {
  VaultRegistry internal registry;

  address internal factory = makeAddr("factory");
  address internal guardian = makeAddr("guardian");
  address internal guardian2 = makeAddr("guardian2");
  address internal asset = makeAddr("asset");
  address internal vault = makeAddr("vault");
  address internal vault2 = makeAddr("vault2");

  function setUp() public {
    registry = new VaultRegistry(address(this));
    registry.setFactory(factory);
  }

  function testOnlyFactoryCanRegisterVault() public {
    // Test: solo FACTORY_ROLE puede registrar vaults.
    vm.expectRevert();
    registry.registerVault(vault, guardian, asset);

    vm.prank(factory);
    registry.registerVault(vault, guardian, asset);

    assertTrue(registry.isRegistered(vault));
  }

  function testRegisterVaultRejectsZeroAddressInputs() public {
    // Test: registerVault revierte para vault/guardian/asset en cero.
    vm.startPrank(factory);
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    registry.registerVault(address(0), guardian, asset);

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    registry.registerVault(vault, address(0), asset);

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    registry.registerVault(vault, guardian, address(0));
    vm.stopPrank();
  }

  function testCannotRegisterDuplicateVaultOrPair() public {
    // Test: no se puede duplicar ni la address del vault ni el par asset/guardian.
    vm.startPrank(factory);
    registry.registerVault(vault, guardian, asset);

    vm.expectRevert(VaultRegistry.VaultRegistry__AlreadyRegistered.selector);
    registry.registerVault(vault, guardian2, asset);

    vm.expectRevert(VaultRegistry.VaultRegistry__PairAlreadyExists.selector);
    registry.registerVault(vault2, guardian, asset);
    vm.stopPrank();
  }

  function testQueriesByAssetAndGuardianReturnRegisteredVaults() public {
    // Test: los índices por asset y guardian deben reflejar lo registrado.
    vm.startPrank(factory);
    registry.registerVault(vault, guardian, asset);
    registry.registerVault(vault2, guardian2, asset);
    vm.stopPrank();

    address[] memory byAsset = registry.getVaultsByAsset(asset);
    address[] memory byGuardian = registry.getVaultsByGuardian(guardian);

    assertEq(byAsset.length, 2);
    assertEq(byGuardian.length, 1);
    assertEq(byGuardian[0], vault);
    assertEq(registry.getVaultByAssetAndGuardian(asset, guardian), vault);
  }

  function testDeactivateVaultByAdminAndByGuardian() public {
    // Test: admin o guardian propietario pueden desactivar un vault activo.
    vm.prank(factory);
    registry.registerVault(vault, guardian, asset);

    registry.deactivateVault(vault);
    assertFalse(registry.isActiveVault(vault));

    vm.prank(factory);
    registry.registerVault(vault2, guardian, makeAddr("asset2"));

    vm.prank(guardian);
    registry.deactivateOwnVault(vault2);
    assertFalse(registry.isActiveVault(vault2));
  }

  function testCannotDeactivateTwice() public {
    // Test: desactivar dos veces el mismo vault debe revertir.
    vm.prank(factory);
    registry.registerVault(vault, guardian, asset);

    registry.deactivateVault(vault);

    vm.expectRevert(VaultRegistry.VaultRegistry__VaultAlreadyInactive.selector);
    registry.deactivateVault(vault);
  }

  function testSetFactoryValidatesZeroAddress() public {
    // Test: setFactory revierte con zero address.
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    registry.setFactory(address(0));
  }

  function testDeactivateOwnVaultValidationPaths() public {
    // Test: deactivateOwnVault revierte si no es guardian o vault no registrado.
    vm.expectRevert(VaultRegistry.VaultRegistry__VaultNotRegistered.selector);
    registry.deactivateOwnVault(vault);

    vm.prank(factory);
    registry.registerVault(vault, guardian, asset);

    vm.prank(guardian2);
    vm.expectRevert(VaultRegistry.VaultRegistry__NotVaultGuardian.selector);
    registry.deactivateOwnVault(vault);
  }

  function testGetVaultDetailAndDeactivateRevertsForUnregistered() public {
    // Test: getVaultDetail y deactivateVault revierten para vault no registrado.
    vm.expectRevert(VaultRegistry.VaultRegistry__VaultNotRegistered.selector);
    registry.getVaultDetail(vault);

    vm.expectRevert(VaultRegistry.VaultRegistry__VaultNotRegistered.selector);
    registry.deactivateVault(vault);
  }

  function testGlobalCountersAndLists() public {
    // Test: getters globales devuelven conteos/listas consistentes.
    vm.startPrank(factory);
    registry.registerVault(vault, guardian, asset);
    registry.registerVault(vault2, guardian2, asset);
    vm.stopPrank();

    address[] memory allVaults = registry.getAllVaults();
    assertEq(allVaults.length, 2);
    assertEq(registry.totalVaults(), 2);
    assertEq(registry.totalVaultsByAsset(asset), 2);
    assertEq(registry.totalVaultsByGuardian(guardian), 1);
    assertTrue(registry.isActiveVault(vault));
    assertFalse(registry.isActiveVault(makeAddr("unregistered")));
  }
}
