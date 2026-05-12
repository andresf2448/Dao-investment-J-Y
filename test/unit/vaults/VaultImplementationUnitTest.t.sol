// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VaultImplementation} from "../../../contracts/vaults/implementations/VaultImplementation.sol";
import {ProtocolCore} from "../../../contracts/core/ProtocolCore.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {MockStrategyAdapter} from "../../mocks/MockStrategyAdapter.sol";
import {MockStrategyRouterNoop} from "../../mocks/MockStrategyRouterNoop.sol";
import {MockNoDataReverter} from "../../mocks/MockNoDataReverter.sol";
import {CommonErrors} from "../../../contracts/libraries/errors/CommonErrors.sol";

contract VaultImplementationUnitTest is Test {
  VaultImplementation internal implementation;
  VaultImplementation internal vault;
  ProtocolCore internal core;
  MockERC20 internal asset;
  MockStrategyRouterNoop internal router;

  address internal guardian = makeAddr("guardian");
  address internal factory = makeAddr("factory");
  address internal newRouter = makeAddr("newRouter");

  function setUp() public {
    asset = new MockERC20("Asset", "AST", 18);
    router = new MockStrategyRouterNoop();

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

    implementation = new VaultImplementation();
    vault = VaultImplementation(payable(Clones.clone(address(implementation))));

    vm.prank(factory);
    vault.initialize(address(asset), "Vault", "vAST", guardian, address(this), factory, address(router), address(core));

    asset.mint(address(this), 2_000e18);
    asset.approve(address(vault), type(uint256).max);
    vault.deposit(1_000e18, address(this));
  }

  function testImplementationDirectInitializeIsBlocked() public {
    // Test: la implementación directa no se puede inicializar.
    vm.expectRevert();
    implementation.initialize(address(asset), "x", "x", guardian, address(this), factory, address(router), address(core));
  }

  function testCloneInitializeRequiresFactoryCaller() public {
    // Test: un clone solo se inicializa si msg.sender coincide con factory.
    VaultImplementation freshClone = VaultImplementation(payable(Clones.clone(address(implementation))));

    vm.prank(makeAddr("other"));
    vm.expectRevert(VaultImplementation.VaultImplementation__NotFactory.selector);
    freshClone.initialize(address(asset), "Vault", "vAST", guardian, address(this), factory, address(router), address(core));
  }

  function testSetRouterRotatesStrategyExecutorRole() public {
    // Test: setRouter revoca rol del router anterior y lo otorga al nuevo.
    bytes32 role = vault.STRATEGY_EXECUTOR_ROLE();
    assertTrue(vault.hasRole(role, address(router)));

    vault.setRouter(newRouter);

    assertFalse(vault.hasRole(role, address(router)));
    assertTrue(vault.hasRole(role, newRouter));
  }

  function testDepositAndMintBlockedByPauseFlags() public {
    // Test: pause local y pausa global en ProtocolCore bloquean deposit/mint.
    vault.pause();

    vm.expectRevert();
    vault.deposit(1e18, address(this));

    vault.unpause();

    core.pauseVaultDeposits();

    vm.expectRevert(VaultImplementation.VaultImplementation__DepositsPaused.selector);
    vault.deposit(1e18, address(this));

    vm.expectRevert(VaultImplementation.VaultImplementation__DepositsPaused.selector);
    vault.mint(1e18, address(this));
  }

  function testExecuteStrategyAllocationValidation() public {
    // Test: executeStrategy revierte con arrays inválidos o porcentajes > 100%.
    vm.prank(guardian);
    vm.expectRevert(VaultImplementation.VaultImplementation__InvalidStrategyAllocation.selector);
    vault.executeStrategy(new address[](0), new uint256[](0), 0);

    address[] memory adapters = new address[](2);
    adapters[0] = makeAddr("a1");
    adapters[1] = makeAddr("a2");

    uint256[] memory allocations = new uint256[](1);
    allocations[0] = 10_000;

    vm.prank(guardian);
    vm.expectRevert(VaultImplementation.VaultImplementation__InvalidStrategyAllocation.selector);
    vault.executeStrategy(adapters, allocations, 0);

    uint256[] memory overAlloc = new uint256[](2);
    overAlloc[0] = 6_000;
    overAlloc[1] = 5_000;

    vm.prank(guardian);
    vm.expectRevert(VaultImplementation.VaultImplementation__InvalidPercentage.selector);
    vault.executeStrategy(adapters, overAlloc, 0);
  }

  function testExecuteFromRouterAuthorizationAndFailurePath() public {
    // Test: executeFromRouter exige role, target no-cero y traduce revert vacío a ExternalCallFailed.
    vm.expectRevert();
    vault.executeFromRouter(address(this), 0, "");

    vm.prank(address(router));
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    vault.executeFromRouter(address(0), 0, "");

    MockNoDataReverter reverter = new MockNoDataReverter();

    vm.prank(address(router));
    vm.expectRevert(VaultImplementation.VaultImplementation__ExternalCallFailed.selector);
    vault.executeFromRouter(address(reverter), 0, hex"1234");
  }

  function testApproveTokenFromRouterValidationsAndSuccess() public {
    // Test: approveTokenFromRouter valida parámetros y actualiza allowance.
    vm.prank(address(router));
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    vault.approveTokenFromRouter(address(0), makeAddr("spender"), 1);

    vm.prank(address(router));
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    vault.approveTokenFromRouter(address(asset), address(0), 1);

    address spender = makeAddr("spender");
    vm.prank(address(router));
    vault.approveTokenFromRouter(address(asset), spender, 99);

    assertEq(IERC20(address(asset)).allowance(address(vault), spender), 99);
  }

  function testSetCoreAndGetActiveAdapters() public {
    // Test: setCore actualiza dependencia y getActiveAdapters refleja estrategia activa.
    address newCore = makeAddr("newCore");
    vault.setCore(newCore);
    assertEq(vault.core(), newCore);

    address adapterA = makeAddr("adapterA");
    address[] memory adapters = new address[](1);
    adapters[0] = adapterA;
    uint256[] memory allocs = new uint256[](1);
    allocs[0] = 10_000;

    vm.prank(guardian);
    vault.executeStrategy(adapters, allocs, 0);

    address[] memory active = vault.getActiveAdapters();
    assertEq(active.length, 1);
    assertEq(active[0], adapterA);
  }

  function testDivestStrategyOnlyGuardian() public {
    // Test: divestStrategy debe revertir si no lo llama guardian.
    vm.expectRevert();
    vault.divestStrategy();
  }

  function testStrategyRotationMarksOldAdapterAsRetired() public {
    // Test: al rotar estrategia, adapter anterior queda en estado Retired y nuevo en Active.
    address adapterA = makeAddr("adapterA");
    address adapterB = makeAddr("adapterB");

    address[] memory firstAdapters = new address[](1);
    firstAdapters[0] = adapterA;
    uint256[] memory firstAllocs = new uint256[](1);
    firstAllocs[0] = 10_000;

    vm.prank(guardian);
    vault.executeStrategy(firstAdapters, firstAllocs, 0);

    address[] memory secondAdapters = new address[](1);
    secondAdapters[0] = adapterB;
    uint256[] memory secondAllocs = new uint256[](1);
    secondAllocs[0] = 10_000;

    vm.prank(guardian);
    vault.executeStrategy(secondAdapters, secondAllocs, 0);

    (uint16 bpsA, VaultImplementation.AdapterStatus statusA) = vault.listAdapters(adapterA);
    (uint16 bpsB, VaultImplementation.AdapterStatus statusB) = vault.listAdapters(adapterB);

    assertEq(bpsA, 0);
    assertEq(uint256(statusA), uint256(VaultImplementation.AdapterStatus.Retired));
    assertEq(bpsB, 10_000);
    assertEq(uint256(statusB), uint256(VaultImplementation.AdapterStatus.Active));
  }

  function testTotalAssetsIncludesReportedAdapterAssets() public {
    // Test: totalAssets suma balance idle + assets reportados por adapters activos.
    MockStrategyAdapter adapter = new MockStrategyAdapter(makeAddr("pool"));
    adapter.setReportedAssets(777e18);

    address[] memory adapters = new address[](1);
    adapters[0] = address(adapter);
    uint256[] memory allocs = new uint256[](1);
    allocs[0] = 10_000;

    vm.prank(guardian);
    vault.executeStrategy(adapters, allocs, 0);

    assertEq(vault.totalAssets(), 1_000e18 + 777e18);
  }
}
