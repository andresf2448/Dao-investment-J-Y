// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RiskManager} from "../../../contracts/execution/RiskManager.sol";
import {MockV3AggregatorControlled} from "../../mocks/MockV3AggregatorControlled.sol";
import {CommonErrors} from "../../../contracts/libraries/errors/CommonErrors.sol";

contract RiskManagerUnitTest is Test {
  RiskManager internal riskManager;
  MockV3AggregatorControlled internal feed;

  address internal manager = makeAddr("manager");
  address internal emergency = makeAddr("emergency");
  address internal outsider = makeAddr("outsider");
  address internal asset = makeAddr("asset");

  function setUp() public {
    feed = new MockV3AggregatorControlled(8, 1e8);

    RiskManager impl = new RiskManager();
    riskManager = RiskManager(
      address(new ERC1967Proxy(address(impl), abi.encodeCall(RiskManager.initialize, (manager, emergency))))
    );
  }

  function testSetAssetConfigRoleAndValidationChecks() public {
    // Test: setAssetConfig exige manager y valida heartbeat/rangos depeg.
    vm.prank(outsider);
    vm.expectRevert();
    riskManager.setAssetConfig(asset, address(feed), 1 days, false, 0, 0, true);

    vm.prank(manager);
    vm.expectRevert(RiskManager.RiskManager__InvalidHeartbeat.selector);
    riskManager.setAssetConfig(asset, address(feed), 0, false, 0, 0, true);

    vm.startPrank(manager);
    vm.expectRevert(RiskManager.RiskManager__InvalidBpsRange.selector);
    riskManager.setAssetConfig(asset, address(feed), 1 days, true, 0, 10_200, true);

    vm.expectRevert(RiskManager.RiskManager__InvalidBpsRange.selector);
    riskManager.setAssetConfig(asset, address(feed), 1 days, true, 10_100, 10_000, true);

    vm.expectRevert(RiskManager.RiskManager__InvalidBpsRange.selector);
    riskManager.setAssetConfig(asset, address(feed), 1 days, false, 9_900, 10_100, true);
    vm.stopPrank();
  }

  function testValidateExecutionForStableAssetDepegBoundaries() public {
    // Test: stable asset revierte fuera de banda y pasa dentro del rango.
    vm.prank(manager);
    riskManager.setAssetConfig(asset, address(feed), 1 days, true, 9_900, 10_100, true);

    feed.setData(8, int256(0.98e8), 1, 1, block.timestamp);
    vm.expectRevert(RiskManager.RiskManager__DepegDetected.selector);
    riskManager.validateExecution(asset);

    feed.setData(8, int256(1e8), 2, 2, block.timestamp);
    riskManager.validateExecution(asset);

    feed.setData(8, int256(1.02e8), 3, 3, block.timestamp);
    vm.expectRevert(RiskManager.RiskManager__DepegDetected.selector);
    riskManager.validateExecution(asset);
  }

  function testValidateExecutionForInvalidPriceAndRound() public {
    // Test: validateExecution revierte por precio <= 0, stale o round inválido.
    vm.prank(manager);
    riskManager.setAssetConfig(asset, address(feed), 1 days, false, 0, 0, true);

    feed.setData(8, 0, 1, 1, block.timestamp);
    vm.expectRevert(RiskManager.RiskManager__InvalidPrice.selector);
    riskManager.validateExecution(asset);

    feed.setData(8, 1e8, 2, 1, block.timestamp);
    vm.expectRevert(RiskManager.RiskManager__InvalidRound.selector);
    riskManager.validateExecution(asset);

    vm.warp(30 days);
    feed.setData(8, 1e8, 3, 3, block.timestamp - 2 days);
    vm.expectRevert(RiskManager.RiskManager__StalePrice.selector);
    riskManager.validateExecution(asset);
  }

  function testPauseAndUnpauseExecutionAndIsAssetHealthy() public {
    // Test: pausar ejecución bloquea validateExecution y marca unhealthy.
    vm.prank(manager);
    riskManager.setAssetConfig(asset, address(feed), 1 days, false, 0, 0, true);

    vm.prank(emergency);
    riskManager.pauseAdapterExecution();

    vm.expectRevert(RiskManager.RiskManager__ExecutionPaused.selector);
    riskManager.validateExecution(asset);
    assertFalse(riskManager.isAssetHealthy(asset));

    vm.prank(emergency);
    riskManager.unpauseAdapterExecution();
    assertTrue(riskManager.isAssetHealthy(asset));
  }

  function testGetValidatedPriceRevertsWhenAssetDisabledOrFeedZero() public {
    // Test: getValidatedPrice revierte si asset no está enabled o feed es cero.
    vm.expectRevert(RiskManager.RiskManager__AssetNotEnabled.selector);
    riskManager.getValidatedPrice(asset);

    vm.prank(manager);
    riskManager.setAssetConfig(asset, address(feed), 1 days, false, 0, 0, false);

    vm.expectRevert(RiskManager.RiskManager__AssetNotEnabled.selector);
    riskManager.getValidatedPrice(asset);
  }

  function testGetAssetConfigAndFieldsExposeStoredValues() public {
    // Test: getAssetConfig y getAssetConfigFields reflejan exactamente la configuración guardada.
    vm.prank(manager);
    riskManager.setAssetConfig(asset, address(feed), 12 hours, true, 9_900, 10_100, true);

    RiskManager.AssetConfig memory cfg = riskManager.getAssetConfig(asset);
    assertEq(cfg.feed, address(feed));
    assertEq(cfg.heartbeat, 12 hours);
    assertTrue(cfg.isStable);
    assertEq(cfg.depegMinBps, 9_900);
    assertEq(cfg.depegMaxBps, 10_100);
    assertTrue(cfg.enabled);

    (address f, uint48 hb, bool st, uint16 minBps, uint16 maxBps, bool en) = riskManager.getAssetConfigFields(asset);
    assertEq(f, address(feed));
    assertEq(hb, 12 hours);
    assertTrue(st);
    assertEq(minBps, 9_900);
    assertEq(maxBps, 10_100);
    assertTrue(en);
  }

  function testWithdrawNativeValidations() public {
    // Test: withdrawNative valida to, amount y balance.
    vm.prank(manager);
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    riskManager.withdrawNative(payable(address(0)), 1);

    vm.prank(manager);
    vm.expectRevert(CommonErrors.ZeroAmount.selector);
    riskManager.withdrawNative(payable(manager), 0);

    vm.prank(manager);
    vm.expectRevert(RiskManager.RiskManager__InsufficientNativeBalance.selector);
    riskManager.withdrawNative(payable(manager), 1);
  }

  function testWithdrawNativeSuccessPath() public {
    // Test: withdrawNative transfiere ETH correctamente cuando hay balance.
    vm.deal(address(riskManager), 2 ether);
    uint256 before = manager.balance;

    vm.prank(manager);
    riskManager.withdrawNative(payable(manager), 1 ether);

    assertEq(manager.balance, before + 1 ether);
  }
}
