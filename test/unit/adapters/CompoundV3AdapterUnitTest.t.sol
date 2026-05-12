// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {CompoundV3Adapter} from "../../../contracts/adapters/compound/CompoundV3Adapter.sol";
import {MockCompoundComet} from "../../mocks/MockCompoundComet.sol";
import {MockVaultExecutor4626} from "../../mocks/MockVaultExecutor4626.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {CommonErrors} from "../../../contracts/libraries/errors/CommonErrors.sol";

contract CompoundV3AdapterUnitTest is Test {
  CompoundV3Adapter internal adapter;
  MockCompoundComet internal comet;
  MockVaultExecutor4626 internal vault;
  MockERC20 internal asset;

  address internal router = makeAddr("router");

  function setUp() public {
    asset = new MockERC20("Asset", "AST", 18);
    comet = new MockCompoundComet();
    vault = new MockVaultExecutor4626(address(asset));
    adapter = new CompoundV3Adapter(router, address(comet));

    asset.mint(address(vault), 1_000e18);
  }

  function testConstructorRevertsForZeroAddresses() public {
    // Test: constructor debe revertir si router o comet son address(0).
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    new CompoundV3Adapter(address(0), address(comet));

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    new CompoundV3Adapter(router, address(0));
  }

  function testExecuteOnlyRouter() public {
    // Test: execute solo puede ser llamado por router.
    vm.expectRevert(CompoundV3Adapter.CompoundV3Adapter__NotRouter.selector);
    adapter.execute(address(vault), 0, 1e18);
  }

  function testExecuteRevertsForZeroVaultZeroAmountAndInvalidAction() public {
    // Test: execute revierte por vault cero, amount cero o action inválida.
    vm.prank(router);
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    adapter.execute(address(0), 0, 1e18);

    vm.prank(router);
    vm.expectRevert(CommonErrors.ZeroAmount.selector);
    adapter.execute(address(vault), 0, 0);

    vm.prank(router);
    vm.expectRevert(CompoundV3Adapter.CompoundV3Adapter__InvalidAction.selector);
    adapter.execute(address(vault), 2, 1e18);
  }

  function testDepositFlowApprovesAndSupplies() public {
    // Test: acción Deposit aprueba y mueve fondos del vault al comet.
    vm.prank(router);
    adapter.execute(address(vault), 0, 120e18);

    assertEq(comet.deposits(address(vault), address(asset)), 120e18);
  }

  function testWithdrawFlowPullsBackFundsToVault() public {
    // Test: acción Withdraw devuelve fondos al vault.
    vm.prank(router);
    adapter.execute(address(vault), 0, 200e18);

    uint256 beforeVaultBalance = asset.balanceOf(address(vault));

    vm.prank(router);
    adapter.execute(address(vault), 1, 80e18);

    assertEq(asset.balanceOf(address(vault)), beforeVaultBalance + 80e18);
    assertEq(comet.deposits(address(vault), address(asset)), 120e18);
  }

  function testTotalAssetsAndPoolAddress() public {
    // Test: totalAssets y poolAddress reflejan valores esperados.
    vm.prank(router);
    adapter.execute(address(vault), 0, 50e18);

    assertEq(adapter.totalAssets(address(vault), address(asset)), 50e18);
    assertEq(adapter.poolAddress(), address(comet));
  }
}
