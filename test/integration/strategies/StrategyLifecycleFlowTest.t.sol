// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ProtocolCore} from "../../../contracts/core/ProtocolCore.sol";
import {RiskManager} from "../../../contracts/execution/RiskManager.sol";
import {StrategyRouter} from "../../../contracts/execution/StrategyRouter.sol";
import {VaultRegistry} from "../../../contracts/vaults/registry/VaultRegistry.sol";
import {IVaultRegistry} from "../../../contracts/interfaces/vaults/IVaultRegistry.sol";
import {VaultFactory} from "../../../contracts/vaults/factory/VaultFactory.sol";
import {VaultImplementation} from "../../../contracts/vaults/implementations/VaultImplementation.sol";
import {AaveV3Adapter} from "../../../contracts/adapters/aave/AaveV3Adapter.sol";
import {MockAavePool} from "../../mocks/MockAavePool.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {MockGuardianStatus} from "../../mocks/MockGuardianStatus.sol";
import {MockV3AggregatorLocal} from "../../mocks/MockV3AggregatorLocal.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StrategyLifecycleFlowTest is Test {
  ProtocolCore internal core;
  RiskManager internal riskManager;
  StrategyRouter internal router;
  VaultRegistry internal registry;
  VaultFactory internal factory;
  VaultImplementation internal implementation;
  MockGuardianStatus internal guardianStatus;

  MockAavePool internal aavePool;
  AaveV3Adapter internal aaveAdapter;

  MockERC20 internal asset;
  MockV3AggregatorLocal internal priceFeed;

  VaultImplementation internal vault;

  address internal guardian = makeAddr("guardian");
  address internal investor = makeAddr("investor");

  function setUp() public {
    asset = new MockERC20("Asset", "AST", 18);

    address[] memory allowedGenesisTokens = new address[](1);
    allowedGenesisTokens[0] = address(asset);
    ProtocolCore coreImplementation = new ProtocolCore();
    core = ProtocolCore(
      address(
        new ERC1967Proxy(
          address(coreImplementation),
          abi.encodeCall(ProtocolCore.initialize, (payable(address(this)), address(this), allowedGenesisTokens, address(asset)))
        )
      )
    );

    RiskManager riskManagerImplementation = new RiskManager();
    riskManager = RiskManager(
      address(
        new ERC1967Proxy(
          address(riskManagerImplementation), abi.encodeCall(RiskManager.initialize, (address(this), address(this)))
        )
      )
    );

    priceFeed = new MockV3AggregatorLocal(8, 1e8);
    riskManager.setAssetConfig(address(asset), address(priceFeed), 1 days, false, 0, 0, true);

    registry = new VaultRegistry(address(this));

    StrategyRouter routerImplementation = new StrategyRouter();
    router = StrategyRouter(
      address(
        new ERC1967Proxy(
          address(routerImplementation),
          abi.encodeCall(
            StrategyRouter.initialize, (address(this), address(riskManager), IVaultRegistry(address(registry)))
          )
        )
      )
    );

    implementation = new VaultImplementation();
    guardianStatus = new MockGuardianStatus();
    guardianStatus.setActive(guardian, true);

    factory = new VaultFactory(
      address(this),
      address(implementation),
      address(guardianStatus),
      address(registry),
      address(router),
      address(core)
    );

    registry.setFactory(address(factory));

    vm.prank(guardian);
    (address deployedVault,) = factory.createVault(address(asset), "Guardian Vault", "gAST");
    vault = VaultImplementation(deployedVault);

    aavePool = new MockAavePool();
    aaveAdapter = new AaveV3Adapter(address(router), address(aavePool));
    router.setAdapterAllowed(address(aaveAdapter), true);

    asset.mint(investor, 2_000e18);
    vm.prank(investor);
    asset.approve(address(vault), type(uint256).max);
  }

  function testStrategyLifecycleDepositInvestWithdrawAndRebalance() public {
    // Test: flujo completo deposit -> invest -> withdraw parcial (divest/rebalance) -> withdraw total.
    vm.prank(investor);
    vault.deposit(1_000e18, investor);

    address[] memory adapters = new address[](1);
    adapters[0] = address(aaveAdapter);

    uint256[] memory allocations = new uint256[](1);
    allocations[0] = 10_000;

    vm.prank(guardian);
    vault.executeStrategy(adapters, allocations, 0);

    assertEq(aavePool.deposits(address(vault), address(asset)), 1_000e18);
    assertEq(vault.totalAssets(), 1_000e18);

    vm.prank(investor);
    vault.withdraw(200e18, investor, investor);

    assertEq(asset.balanceOf(investor), 1_200e18);
    assertEq(vault.totalAssets(), 800e18);

    uint256 shares = vault.balanceOf(investor);
    vm.prank(investor);
    vault.redeem(shares, investor, investor);

    assertEq(vault.totalAssets(), 0);
    assertEq(asset.balanceOf(investor), 2_000e18);
  }

  function testRiskManagerPauseBlocksInvestExecution() public {
    // Test: con RiskManager pausado, executeStrategy debe revertir al validar ejecución.
    vm.prank(investor);
    vault.deposit(500e18, investor);

    riskManager.pauseAdapterExecution();

    address[] memory adapters = new address[](1);
    adapters[0] = address(aaveAdapter);

    uint256[] memory allocations = new uint256[](1);
    allocations[0] = 10_000;

    vm.prank(guardian);
    vm.expectRevert(RiskManager.RiskManager__ExecutionPaused.selector);
    vault.executeStrategy(adapters, allocations, 0);
  }

  function testNotAllowedAdapterDoesNotMoveFunds() public {
    // Test: si el adapter no está permitido, router lo ignora y no mueve fondos.
    vm.prank(investor);
    vault.deposit(300e18, investor);

    router.setAdapterAllowed(address(aaveAdapter), false);

    address[] memory adapters = new address[](1);
    adapters[0] = address(aaveAdapter);

    uint256[] memory allocations = new uint256[](1);
    allocations[0] = 10_000;

    vm.prank(guardian);
    vault.executeStrategy(adapters, allocations, 0);

    assertEq(aavePool.deposits(address(vault), address(asset)), 0);
    assertEq(asset.balanceOf(address(vault)), 300e18);
  }
}
