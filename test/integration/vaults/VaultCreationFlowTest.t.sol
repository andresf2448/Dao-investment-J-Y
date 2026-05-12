// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ProtocolCore} from "../../../contracts/core/ProtocolCore.sol";
import {VaultRegistry} from "../../../contracts/vaults/registry/VaultRegistry.sol";
import {VaultFactory} from "../../../contracts/vaults/factory/VaultFactory.sol";
import {VaultImplementation} from "../../../contracts/vaults/implementations/VaultImplementation.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {MockGuardianStatus} from "../../mocks/MockGuardianStatus.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultCreationFlowTest is Test {
  ProtocolCore internal core;
  VaultRegistry internal registry;
  VaultFactory internal factory;
  VaultImplementation internal implementation;
  MockGuardianStatus internal guardianStatus;
  MockERC20 internal asset;

  address internal guardian = makeAddr("guardian");
  address internal router = makeAddr("router");
  address internal emergency = makeAddr("emergency");

  function setUp() public {
    asset = new MockERC20("Asset", "AST", 18);

    address[] memory allowedGenesisTokens = new address[](1);
    allowedGenesisTokens[0] = address(asset);
    ProtocolCore coreImplementation = new ProtocolCore();
    core = ProtocolCore(
      address(
        new ERC1967Proxy(
          address(coreImplementation),
          abi.encodeCall(
            ProtocolCore.initialize, (payable(address(this)), emergency, allowedGenesisTokens, address(asset))
          )
        )
      )
    );

    registry = new VaultRegistry(address(this));
    implementation = new VaultImplementation();
    guardianStatus = new MockGuardianStatus();

    factory = new VaultFactory(
      address(this),
      address(implementation),
      address(guardianStatus),
      address(registry),
      router,
      address(core)
    );

    registry.setFactory(address(factory));
    guardianStatus.setActive(guardian, true);
  }

  function testActiveGuardianCreatesVaultAndRegistryStoresIt() public {
    // Test: guardian activo crea vault, clone se inicializa y registry guarda el par asset/guardian.
    vm.prank(guardian);
    (address vault, bytes32 salt) = factory.createVault(address(asset), "Guardian Vault", "gAST");

    (bytes32 expectedSalt, address predicted) = factory.predictVaultAddress(guardian, address(asset));

    assertEq(salt, expectedSalt);
    assertEq(vault, predicted);
    assertEq(registry.getVaultByAssetAndGuardian(address(asset), guardian), vault);

    VaultImplementation createdVault = VaultImplementation(vault);
    assertEq(createdVault.guardian(), guardian);
    assertEq(createdVault.factory(), address(factory));
    assertEq(createdVault.router(), router);
    assertEq(createdVault.core(), address(core));
    assertEq(createdVault.asset(), address(asset));
    assertEq(createdVault.name(), "Guardian Vault");
    assertEq(createdVault.symbol(), "gAST");
  }

  function testCannotCreateSecondVaultForSameGuardianAndAsset() public {
    // Test: no se puede crear un segundo vault para el mismo guardian/asset.
    vm.startPrank(guardian);
    factory.createVault(address(asset), "Vault A", "vA");

    vm.expectRevert(VaultFactory.VaultFactory__VaultAlreadyExists.selector);
    factory.createVault(address(asset), "Vault B", "vB");
    vm.stopPrank();
  }

  function testInactiveGuardianCannotCreateVault() public {
    // Test: guardian inactivo debe revertir al crear vault.
    guardianStatus.setActive(guardian, false);

    vm.prank(guardian);
    vm.expectRevert(VaultFactory.VaultFactory__GuardianNotActive.selector);
    factory.createVault(address(asset), "Vault", "vAST");
  }

  function testUnsupportedAssetCannotCreateVault() public {
    // Test: crear vault con asset no soportado debe revertir.
    MockERC20 unsupported = new MockERC20("UNSUP", "UNS", 18);

    vm.prank(guardian);
    vm.expectRevert(VaultFactory.VaultFactory__UnsupportedAsset.selector);
    factory.createVault(address(unsupported), "Vault", "vUNS");
  }

  function testPauseVaultCreationBlocksFactory() public {
    // Test: si ProtocolCore pausa creación de vaults, factory debe revertir.
    vm.prank(emergency);
    core.pauseVaultCreation();

    vm.prank(guardian);
    vm.expectRevert(VaultFactory.VaultFactory__VaultCreationPaused.selector);
    factory.createVault(address(asset), "Vault", "vAST");
  }
}
