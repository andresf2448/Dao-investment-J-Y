// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {GenesisBonding} from "../../../contracts/bootstrap/GenesisBonding.sol";
import {GovernanceToken} from "../../../contracts/governance/GovernanceToken.sol";
import {IGovernanceToken} from "../../../contracts/interfaces/governance/IGovernanceToken.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {CommonErrors} from "../../../contracts/libraries/errors/CommonErrors.sol";

contract GenesisBondingUnitTest is Test {
  GenesisBonding internal bonding;
  GovernanceToken internal governanceToken;
  MockERC20 internal paymentToken;
  MockERC20 internal secondPaymentToken;
  MockERC20 internal foreignToken;

  address internal sweeper = makeAddr("sweeper");
  address internal treasury = makeAddr("treasury");
  address internal buyer = makeAddr("buyer");

  uint256 internal constant RATE = 5;

  function setUp() public {
    governanceToken = new GovernanceToken(address(this));
    paymentToken = new MockERC20("USDC", "USDC", 6);
    secondPaymentToken = new MockERC20("DAI", "DAI", 18);
    foreignToken = new MockERC20("RND", "RND", 18);

    address[] memory allowedTokens = new address[](1);
    allowedTokens[0] = address(paymentToken);

    bonding = new GenesisBonding(
      address(this), sweeper, allowedTokens, IGovernanceToken(address(governanceToken)), treasury, RATE
    );

    governanceToken.grantRole(governanceToken.MINTER_ROLE(), address(bonding));

    paymentToken.mint(buyer, 1_000_000e6);
    foreignToken.mint(address(bonding), 250e18);

    vm.prank(buyer);
    paymentToken.approve(address(bonding), type(uint256).max);
  }

  function testConstructorRevertsWhenRateIsZero() public {
    // Test: constructor debe revertir si rate = 0.
    address[] memory allowedTokens = new address[](1);
    allowedTokens[0] = address(paymentToken);

    vm.expectRevert(GenesisBonding.GenesisBonding__InvalidRate.selector);
    new GenesisBonding(address(this), sweeper, allowedTokens, IGovernanceToken(address(governanceToken)), treasury, 0);
  }

  function testBuyRevertsWithInvalidToken() public {
    // Test: buy debe revertir si el token de pago no está permitido.
    vm.prank(buyer);
    vm.expectRevert(GenesisBonding.GenesisBonding__InvalidToken.selector);
    bonding.buy(address(secondPaymentToken), 100e18);
  }

  function testBuyTransfersPaymentAndMintsGovernance() public {
    // Test: buy transfiere payment token al treasury y mintea governance token al comprador.
    vm.prank(buyer);
    bonding.buy(address(paymentToken), 200_000e6);

    assertEq(paymentToken.balanceOf(treasury), 200_000e6);
    assertEq(governanceToken.balanceOf(buyer), 200_000e6 * RATE);
  }

  function testTotalGovernanceTokenPurchasedAccumulates() public {
    // Test: totalGovernanceTokenPurchased debe acumular correctamente múltiples compras.
    vm.startPrank(buyer);
    bonding.buy(address(paymentToken), 100_000e6);
    bonding.buy(address(paymentToken), 50_000e6);
    vm.stopPrank();

    assertEq(bonding.totalGovernanceTokenPurchased(), (150_000e6 * RATE));
  }

  function testFinalizeBlocksFutureBuysAndClosesMinting() public {
    // Test: finalize debe bloquear compras futuras y marcar minting como finalizado.
    bonding.finalize();

    assertTrue(governanceToken.isMintingFinished());

    vm.prank(buyer);
    vm.expectRevert(GenesisBonding.GenesisBonding__AlreadyFinalized.selector);
    bonding.buy(address(paymentToken), 1e6);
  }

  function testSweepCannotSweepPurchaseOrGovernanceToken() public {
    // Test: sweep no debe permitir barrer token de compra ni governance token.
    vm.prank(sweeper);
    vm.expectRevert(GenesisBonding.GenesisBonding__TokenNotAllowedToSweep.selector);
    bonding.sweep(address(paymentToken));

    vm.prank(sweeper);
    vm.expectRevert(GenesisBonding.GenesisBonding__TokenNotAllowedToSweep.selector);
    bonding.sweep(address(governanceToken));
  }

  function testSweepMovesForeignTokenToTreasury() public {
    // Test: sweep debe mover tokens ajenos al treasury.
    vm.prank(sweeper);
    bonding.sweep(address(foreignToken));

    assertEq(foreignToken.balanceOf(treasury), 250e18);
  }

  function testSetPurchaseTokensAppendsInsteadOfReplacing() public {
    // Test: setPurchaseTokens agrega token nuevo y mantiene habilitado el anterior.
    address[] memory extra = new address[](1);
    extra[0] = address(secondPaymentToken);
    bonding.setPurchaseTokens(extra);

    secondPaymentToken.mint(buyer, 5_000e18);
    vm.prank(buyer);
    secondPaymentToken.approve(address(bonding), type(uint256).max);

    vm.startPrank(buyer);
    bonding.buy(address(paymentToken), 10_000e6);
    bonding.buy(address(secondPaymentToken), 2_000e18);
    vm.stopPrank();

    assertEq(paymentToken.balanceOf(treasury), 10_000e6);
    assertEq(secondPaymentToken.balanceOf(treasury), 2_000e18);
  }

  function testBuyRevertsWithZeroAmount() public {
    // Test: buy debe revertir con amount cero.
    vm.prank(buyer);
    vm.expectRevert(CommonErrors.ZeroAmount.selector);
    bonding.buy(address(paymentToken), 0);
  }
}
