// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ProtocolCore} from "../../../contracts/core/ProtocolCore.sol";
import {Treasury} from "../../../contracts/core/Treasury.sol";
import {GenesisBonding} from "../../../contracts/bootstrap/GenesisBonding.sol";
import {GovernanceToken} from "../../../contracts/governance/GovernanceToken.sol";
import {IGovernanceToken} from "../../../contracts/interfaces/governance/IGovernanceToken.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GenesisTreasuryFlowTest is Test {
  ProtocolCore internal core;
  Treasury internal treasury;
  GenesisBonding internal bonding;
  GovernanceToken internal governanceToken;

  MockERC20 internal paymentToken;
  MockERC20 internal nonGenesisToken;

  address internal sweeper = makeAddr("sweeper");
  address internal buyer = makeAddr("buyer");

  uint256 internal constant RATE = 3;

  function setUp() public {
    paymentToken = new MockERC20("USDC", "USDC", 6);
    nonGenesisToken = new MockERC20("RND", "RND", 18);

    address[] memory allowedGenesisTokens = new address[](1);
    allowedGenesisTokens[0] = address(paymentToken);
    ProtocolCore coreImplementation = new ProtocolCore();
    core = ProtocolCore(
      address(
        new ERC1967Proxy(
          address(coreImplementation),
          abi.encodeCall(
            ProtocolCore.initialize, (payable(address(this)), makeAddr("emergency"), allowedGenesisTokens, address(paymentToken))
          )
        )
      )
    );

    treasury = new Treasury(address(this), sweeper);
    treasury.setProtocolCore(address(core));

    governanceToken = new GovernanceToken(address(this));

    address[] memory saleTokens = new address[](1);
    saleTokens[0] = address(paymentToken);

    bonding = new GenesisBonding(address(this), sweeper, saleTokens, IGovernanceToken(address(governanceToken)), address(treasury), RATE);

    governanceToken.grantRole(governanceToken.MINTER_ROLE(), address(bonding));

    paymentToken.mint(buyer, 500_000e6);
    vm.prank(buyer);
    paymentToken.approve(address(bonding), type(uint256).max);
  }

  function testBuyFlowSendsFundsToTreasuryAndMintsGovernance() public {
    // Test: compra en GenesisBonding manda fondos al Treasury y mintea governance al buyer.
    vm.prank(buyer);
    bonding.buy(address(paymentToken), 200_000e6);

    assertEq(paymentToken.balanceOf(address(treasury)), 200_000e6);
    assertEq(governanceToken.balanceOf(buyer), 200_000e6 * RATE);
    assertEq(bonding.totalGovernanceTokenPurchased(), 200_000e6 * RATE);
  }

  function testFinalizeThenTreasuryWithdrawRulesForGenesisAndNonGenesis() public {
    // Test: tras finalize, compras fallan y Treasury aplica reglas distintas genesis vs non-genesis.
    vm.prank(buyer);
    bonding.buy(address(paymentToken), 100_000e6);

    bonding.finalize();

    vm.prank(buyer);
    vm.expectRevert(GenesisBonding.GenesisBonding__AlreadyFinalized.selector);
    bonding.buy(address(paymentToken), 1e6);

    nonGenesisToken.mint(address(treasury), 50e18);

    treasury.withdrawDaoERC20(address(paymentToken), buyer, 10_000e6);
    assertEq(paymentToken.balanceOf(buyer), (500_000e6 - 100_000e6) + 10_000e6);

    vm.prank(sweeper);
    treasury.withdrawNotAssetDaoERC20(address(nonGenesisToken), buyer, 25e18);
    assertEq(nonGenesisToken.balanceOf(buyer), 25e18);
  }
}
