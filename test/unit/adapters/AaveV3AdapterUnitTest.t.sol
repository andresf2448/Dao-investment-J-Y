// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {AaveV3Adapter} from "../../../contracts/adapters/aave/AaveV3Adapter.sol";
import {MockAavePool} from "../../mocks/MockAavePool.sol";
import {MockVaultExecutor4626} from "../../mocks/MockVaultExecutor4626.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {CommonErrors} from "../../../contracts/libraries/errors/CommonErrors.sol";

contract AaveV3AdapterUnitTest is Test {
  AaveV3Adapter internal adapter;
  MockAavePool internal pool;
  MockVaultExecutor4626 internal vault;
  MockERC20 internal asset;

  address internal router = makeAddr("router");

  function setUp() public {
    asset = new MockERC20("Asset", "AST", 18);
    pool = new MockAavePool();
    vault = new MockVaultExecutor4626(address(asset));
    adapter = new AaveV3Adapter(router, address(pool));

    asset.mint(address(vault), 1_000e18);
  }

  function testConstructorRevertsForZeroAddresses() public {
    // Test: constructor debe revertir si router o pool son address(0).
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    new AaveV3Adapter(address(0), address(pool));

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    new AaveV3Adapter(router, address(0));
  }

  function testExecuteOnlyRouter() public {
    // Test: execute solo puede ser llamado por router.
    vm.expectRevert(AaveV3Adapter.AaveV3Adapter__NotRouter.selector);
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
    vm.expectRevert(AaveV3Adapter.AaveV3Adapter__InvalidAction.selector);
    adapter.execute(address(vault), 2, 1e18);
  }

  function testDepositAndWithdrawFlow() public {
    // Test: deposit y withdraw actualizan balances en pool y vault.
    vm.prank(router);
    adapter.execute(address(vault), 0, 300e18);

    assertEq(pool.deposits(address(vault), address(asset)), 300e18);

    uint256 beforeVaultBalance = asset.balanceOf(address(vault));

    vm.prank(router);
    adapter.execute(address(vault), 1, 120e18);

    assertEq(asset.balanceOf(address(vault)), beforeVaultBalance + 120e18);
    assertEq(pool.deposits(address(vault), address(asset)), 180e18);
  }

  function testTotalAssetsAndPoolAddress() public {
    // Test: totalAssets y poolAddress reflejan el estado real del adapter.
    vm.prank(router);
    adapter.execute(address(vault), 0, 50e18);

    assertEq(adapter.totalAssets(address(vault), address(asset)), 50e18);
    assertEq(adapter.poolAddress(), address(pool));
  }
}
