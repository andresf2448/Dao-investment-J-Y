// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {ProtocolCore} from "../../contracts/core/ProtocolCore.sol";
import {RiskManager} from "../../contracts/execution/RiskManager.sol";
import {StrategyRouter} from "../../contracts/execution/StrategyRouter.sol";
import {VaultRegistry} from "../../contracts/vaults/registry/VaultRegistry.sol";
import {IVaultRegistry} from "../../contracts/interfaces/vaults/IVaultRegistry.sol";
import {VaultFactory} from "../../contracts/vaults/factory/VaultFactory.sol";
import {VaultImplementation} from "../../contracts/vaults/implementations/VaultImplementation.sol";
import {AaveV3Adapter} from "../../contracts/adapters/aave/AaveV3Adapter.sol";
import {MockAavePool} from "../mocks/MockAavePool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockGuardianStatus} from "../mocks/MockGuardianStatus.sol";
import {MockV3AggregatorLocal} from "../mocks/MockV3AggregatorLocal.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultInvariantHandler is Test {
  VaultImplementation internal vault;
  MockERC20 internal asset;
  AaveV3Adapter internal adapter;

  address internal guardian;
  address internal alice;
  address internal bob;

  constructor(
    VaultImplementation vault_,
    MockERC20 asset_,
    AaveV3Adapter adapter_,
    address guardian_,
    address alice_,
    address bob_
  ) {
    vault = vault_;
    asset = asset_;
    adapter = adapter_;
    guardian = guardian_;
    alice = alice_;
    bob = bob_;

    asset.mint(alice, 100_000e18);
    asset.mint(bob, 100_000e18);

    vm.startPrank(alice);
    asset.approve(address(vault), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(bob);
    asset.approve(address(vault), type(uint256).max);
    vm.stopPrank();
  }

  function deposit(uint96 amount, uint8 userSeed) external {
    address actor = userSeed % 2 == 0 ? alice : bob;
    uint256 bounded = bound(uint256(amount), 1e6, 1_000e18);

    vm.prank(actor);
    vault.deposit(bounded, actor);
  }

  function withdraw(uint96 amount, uint8 userSeed) external {
    address actor = userSeed % 2 == 0 ? alice : bob;
    uint256 max = vault.maxWithdraw(actor);
    if (max == 0) return;

    uint256 bounded = bound(uint256(amount), 1, max);

    vm.prank(actor);
    vault.withdraw(bounded, actor, actor);
  }

  function investAll() external {
    address[] memory adapters = new address[](1);
    adapters[0] = address(adapter);

    uint256[] memory allocations = new uint256[](1);
    allocations[0] = 10_000;

    vm.prank(guardian);
    vault.executeStrategy(adapters, allocations, 0);
  }

  function divestAll() external {
    vm.prank(guardian);
    vault.divestStrategy();
  }
}

contract VaultAccountingInvariantTest is StdInvariant, Test {
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
  VaultInvariantHandler internal handler;

  address internal guardian = makeAddr("guardian");
  address internal alice = makeAddr("alice");
  address internal bob = makeAddr("bob");

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
    (address deployedVault,) = factory.createVault(address(asset), "Invariant Vault", "iAST");
    vault = VaultImplementation(deployedVault);

    aavePool = new MockAavePool();
    aaveAdapter = new AaveV3Adapter(address(router), address(aavePool));
    router.setAdapterAllowed(address(aaveAdapter), true);

    handler = new VaultInvariantHandler(vault, asset, aaveAdapter, guardian, alice, bob);

    targetContract(address(handler));
  }

  function invariantTotalAssetsMatchesIdlePlusAdapterBalance() public view {
    // Test: totalAssets siempre coincide con idle vault + balance reportado por adapter activo.
    uint256 expected = asset.balanceOf(address(vault)) + aavePool.deposits(address(vault), address(asset));
    assertEq(vault.totalAssets(), expected);
  }

  function invariantTotalSupplyNeverExceedsTotalAssets() public view {
    // Test: sin yield artificial, la oferta de shares no puede exceder totalAssets.
    assertLe(vault.totalSupply(), vault.totalAssets());
  }
}
