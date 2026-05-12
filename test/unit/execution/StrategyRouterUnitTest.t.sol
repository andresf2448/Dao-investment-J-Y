// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {StrategyRouter} from "../../../contracts/execution/StrategyRouter.sol";
import {VaultRegistry} from "../../../contracts/vaults/registry/VaultRegistry.sol";
import {IVaultRegistry} from "../../../contracts/interfaces/vaults/IVaultRegistry.sol";
import {CommonErrors} from "../../../contracts/libraries/errors/CommonErrors.sol";
import {MockRiskManager} from "../../mocks/MockRiskManager.sol";
import {MockStrategyAdapter} from "../../mocks/MockStrategyAdapter.sol";

contract StrategyRouterUnitTest is Test {
  StrategyRouter internal router;
  VaultRegistry internal registry;
  MockRiskManager internal riskManager;
  MockStrategyAdapter internal adapter;

  address internal activeVault = makeAddr("activeVault");
  address internal inactiveVault = makeAddr("inactiveVault");
  address internal asset = makeAddr("asset");

  function setUp() public {
    registry = new VaultRegistry(address(this));
    registry.setFactory(address(this));
    registry.registerVault(activeVault, makeAddr("guardian"), asset);

    riskManager = new MockRiskManager();
    adapter = new MockStrategyAdapter(makeAddr("pool"));

    StrategyRouter impl = new StrategyRouter();
    router = StrategyRouter(
      address(
        new ERC1967Proxy(
          address(impl), abi.encodeCall(StrategyRouter.initialize, (address(this), address(riskManager), IVaultRegistry(address(registry))))
        )
      )
    );

    router.setAdapterAllowed(address(adapter), true);
  }

  function testExecuteMultipleOnlyVaultCaller() public {
    // Test: executeMultiple requiere vault == msg.sender.
    address[] memory adapters = new address[](1);
    adapters[0] = address(adapter);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 1e18;

    vm.expectRevert(CommonErrors.Unauthorized.selector);
    router.executeMultiple(activeVault, asset, adapters, amounts, 0);
  }

  function testExecuteMultipleValidatesAllocationAndVaultStatus() public {
    // Test: executeMultiple revierte por arrays inválidos o vault inactivo.
    vm.prank(activeVault);
    vm.expectRevert(StrategyRouter.StrategyRouter__InvalidAllocation.selector);
    router.executeMultiple(activeVault, asset, new address[](0), new uint256[](0), 0);

    address[] memory adapters = new address[](1);
    adapters[0] = address(adapter);
    uint256[] memory badAmounts = new uint256[](2);

    vm.prank(activeVault);
    vm.expectRevert(StrategyRouter.StrategyRouter__InvalidAllocation.selector);
    router.executeMultiple(activeVault, asset, adapters, badAmounts, 0);

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 1e18;

    vm.prank(inactiveVault);
    vm.expectRevert(StrategyRouter.StrategyRouter__VaultNotActive.selector);
    router.executeMultiple(inactiveVault, asset, adapters, amounts, 0);
  }

  function testExecuteMultipleSkipsNotAllowedOrDuplicateAdapters() public {
    // Test: executeMultiple ignora adapters no permitidos y duplicados.
    MockStrategyAdapter second = new MockStrategyAdapter(makeAddr("pool2"));

    address[] memory adapters = new address[](3);
    adapters[0] = address(adapter);
    adapters[1] = address(adapter);
    adapters[2] = address(second);

    uint256[] memory amounts = new uint256[](3);
    amounts[0] = 10;
    amounts[1] = 20;
    amounts[2] = 30;

    vm.prank(activeVault);
    router.executeMultiple(activeVault, asset, adapters, amounts, 0);

    assertEq(adapter.executeCalls(), 1);
    assertEq(adapter.lastAmount(), 10);
    assertEq(second.executeCalls(), 0);
  }

  function testExecuteMultipleRevertsWhenRiskManagerValidationFails() public {
    // Test: executeMultiple debe revertir si RiskManager falla la validación.
    riskManager.setShouldRevert(true);

    address[] memory adapters = new address[](1);
    adapters[0] = address(adapter);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 1;

    vm.prank(activeVault);
    vm.expectRevert(MockRiskManager.MockRiskManager__ForcedRevert.selector);
    router.executeMultiple(activeVault, asset, adapters, amounts, 0);
  }

  function testDivestMultipleValidationsAndExecution() public {
    // Test: divestMultiple valida longitudes y ejecuta solo adapters permitidos.
    vm.prank(activeVault);
    vm.expectRevert(StrategyRouter.StrategyRouter__InvalidAllocation.selector);
    router.divestMultiple(activeVault, new address[](0), new uint256[](0));

    address[] memory adapters = new address[](2);
    adapters[0] = address(adapter);
    adapters[1] = makeAddr("notAllowed");

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = 77;
    amounts[1] = 99;

    vm.prank(activeVault);
    router.divestMultiple(activeVault, adapters, amounts);

    assertEq(adapter.executeCalls(), 1);
    assertEq(adapter.lastAction(), router.DIVEST_ACTION());
    assertEq(adapter.lastAmount(), 77);
  }

  function testAdminSettersAndWithdrawNativeValidations() public {
    // Test: setters admin y withdrawNative validan zero address/amount/balance.
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    router.setAdapterAllowed(address(0), true);

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    router.setRiskManager(address(0));

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    router.withdrawNative(payable(address(0)), 1);

    vm.expectRevert(CommonErrors.ZeroAmount.selector);
    router.withdrawNative(payable(address(this)), 0);

    vm.expectRevert(StrategyRouter.StrategyRouter__InsufficientNativeBalance.selector);
    router.withdrawNative(payable(address(this)), 1);
  }

  function testSetAdapterAllowedToggleAndGetAllowedAdapters() public {
    // Test: allowlist de adapters se puede activar/desactivar y consultar.
    address[] memory allowedBefore = router.getAllowedAdapters();
    assertEq(allowedBefore.length, 1);

    router.setAdapterAllowed(address(adapter), false);
    assertFalse(router.isAdapterAllowed(address(adapter)));

    address[] memory allowedAfter = router.getAllowedAdapters();
    assertEq(allowedAfter.length, 0);
  }

  function testSetRiskManagerAndWithdrawNativeSuccess() public {
    // Test: setRiskManager actualiza dependencia y withdrawNative funciona con saldo.
    MockRiskManager replacement = new MockRiskManager();
    router.setRiskManager(address(replacement));
    assertEq(router.riskManager(), address(replacement));

    vm.deal(address(router), 2 ether);
    address payable recipient = payable(makeAddr("recipient"));
    uint256 before = recipient.balance;
    router.withdrawNative(recipient, 1 ether);
    assertEq(recipient.balance, before + 1 ether);
  }
}
