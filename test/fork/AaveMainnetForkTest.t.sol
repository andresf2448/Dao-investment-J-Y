// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AaveV3Adapter} from "../../contracts/adapters/aave/AaveV3Adapter.sol";
import {MockVaultExecutor4626} from "../mocks/MockVaultExecutor4626.sol";
import {HelperConfig} from "../../script/deploy/HelperConfig.s.sol";

contract AaveMainnetForkTest is Test {
  uint256 internal constant INITIAL_VAULT_ASSET = 1_000e6;
  uint256 internal constant INVEST_AMOUNT_ASSET = 200e6;
  uint256 internal constant DIVEST_AMOUNT_ASSET = 75e6;

  address internal router = makeAddr("router");

  address internal assetToken;
  address internal aavePool;
  IERC20 internal asset;
  MockVaultExecutor4626 internal vault;
  AaveV3Adapter internal adapter;

  function setUp() public {
    // Test setup: carga direcciones desde HelperConfig (.env en mainnet) y prepara dependencias solo en fork de mainnet.
    HelperConfig helperConfig = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

    assetToken = networkConfig.allowedVaultToken;
    aavePool = networkConfig.aavePool;
    if (!_isMainnetFork()) return;

    asset = IERC20(assetToken);
    vault = new MockVaultExecutor4626(assetToken);
    adapter = new AaveV3Adapter(router, aavePool);

    deal(assetToken, address(vault), INITIAL_VAULT_ASSET);
  }

  function testFork_ConnectionWithAavePool_DepositAndWithdraw() public {
    // Test: valida conexión real con Aave pool en fork de mainnet ejecutando supply y withdraw vía adapter.
    if (!_isMainnetFork()) return;

    uint256 initialVaultBalance = asset.balanceOf(address(vault));
    assertEq(initialVaultBalance, INITIAL_VAULT_ASSET);

    vm.prank(router);
    adapter.execute(address(vault), 0, INVEST_AMOUNT_ASSET);

    uint256 afterDepositVaultBalance = asset.balanceOf(address(vault));
    assertEq(afterDepositVaultBalance, initialVaultBalance - INVEST_AMOUNT_ASSET);

    vm.prank(router);
    adapter.execute(address(vault), 1, DIVEST_AMOUNT_ASSET);

    uint256 afterWithdrawVaultBalance = asset.balanceOf(address(vault));
    assertEq(afterWithdrawVaultBalance, afterDepositVaultBalance + DIVEST_AMOUNT_ASSET);
  }

  function _isMainnetFork() internal view returns (bool) {
    // Guard: este test se ejecuta solo cuando el runner está sobre fork de Ethereum mainnet.
    return block.chainid == 1 && aavePool.code.length > 0 && assetToken.code.length > 0;
  }
}
