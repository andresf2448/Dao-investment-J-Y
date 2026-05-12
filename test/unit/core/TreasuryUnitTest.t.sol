// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../../contracts/core/Treasury.sol";
import {ProtocolCore} from "../../../contracts/core/ProtocolCore.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {CommonErrors} from "../../../contracts/libraries/errors/CommonErrors.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TreasuryUnitTest is Test {
  Treasury internal treasury;
  ProtocolCore internal core;
  MockERC20 internal genesisToken;
  MockERC20 internal randomToken;

  address internal sweeper = makeAddr("sweeper");
  address internal receiver = makeAddr("receiver");
  address payable internal nativeReceiver = payable(makeAddr("nativeReceiver"));

  function setUp() public {
    genesisToken = new MockERC20("Genesis", "GEN", 18);
    randomToken = new MockERC20("Random", "RND", 18);

    treasury = new Treasury(address(this), sweeper);

    address[] memory allowedGenesisTokens = new address[](1);
    allowedGenesisTokens[0] = address(genesisToken);
    ProtocolCore coreImplementation = new ProtocolCore();
    core = ProtocolCore(
      address(
        new ERC1967Proxy(
          address(coreImplementation),
          abi.encodeCall(
            ProtocolCore.initialize, (payable(address(this)), makeAddr("emergency"), allowedGenesisTokens, address(genesisToken))
          )
        )
      )
    );

    treasury.setProtocolCore(address(core));

    genesisToken.mint(address(treasury), 1_000e18);
    randomToken.mint(address(treasury), 1_000e18);

    vm.deal(address(this), 100 ether);
    payable(address(treasury)).transfer(10 ether);
  }

  function testSetProtocolCoreOnlyAdmin() public {
    // Test: solo el admin puede actualizar protocolCore.
    vm.prank(sweeper);
    vm.expectRevert();
    treasury.setProtocolCore(address(core));
  }

  function testSetProtocolCoreRejectsZeroAddress() public {
    // Test: setProtocolCore debe revertir con address(0).
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    treasury.setProtocolCore(address(0));
  }

  function testWithdrawDaoERC20ForGenesisToken() public {
    // Test: el admin puede retirar tokens genesis por la ruta DAO.
    treasury.withdrawDaoERC20(address(genesisToken), receiver, 200e18);
    assertEq(genesisToken.balanceOf(receiver), 200e18);
  }

  function testWithdrawDaoERC20RevertsForNonGenesisToken() public {
    // Test: retirar token no-genesis por ruta DAO debe revertir.
    vm.expectRevert(Treasury.Treasury__InvalidToken.selector);
    treasury.withdrawDaoERC20(address(randomToken), receiver, 1e18);
  }

  function testWithdrawDaoERC20ValidatesZeroAddressAndZeroAmount() public {
    // Test: retiro DAO ERC20 valida token/to no-cero y amount no-cero.
    vm.expectRevert(Treasury.Treasury__InvalidToken.selector);
    treasury.withdrawDaoERC20(address(0), receiver, 1);

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    treasury.withdrawDaoERC20(address(genesisToken), address(0), 1);

    vm.expectRevert(CommonErrors.ZeroAmount.selector);
    treasury.withdrawDaoERC20(address(genesisToken), receiver, 0);
  }

  function testWithdrawNotAssetDaoERC20OnlySweepRole() public {
    // Test: solo SWEEP_NOT_ASSET_DAO_ROLE puede barrer no-genesis.
    vm.expectRevert();
    treasury.withdrawNotAssetDaoERC20(address(randomToken), receiver, 50e18);

    vm.prank(sweeper);
    treasury.withdrawNotAssetDaoERC20(address(randomToken), receiver, 50e18);
    assertEq(randomToken.balanceOf(receiver), 50e18);
  }

  function testWithdrawNotAssetDaoERC20RejectsGenesisToken() public {
    // Test: barrer token genesis por ruta no-asset debe revertir.
    vm.prank(sweeper);
    vm.expectRevert(Treasury.Treasury__InvalidToken.selector);
    treasury.withdrawNotAssetDaoERC20(address(genesisToken), receiver, 1e18);
  }

  function testWithdrawNotAssetDaoERC20ValidatesZeroAddressAndZeroAmount() public {
    // Test: sweep no-asset valida token/to no-cero y amount no-cero.
    vm.startPrank(sweeper);
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    treasury.withdrawNotAssetDaoERC20(address(0), receiver, 1);

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    treasury.withdrawNotAssetDaoERC20(address(randomToken), address(0), 1);

    vm.expectRevert(CommonErrors.ZeroAmount.selector);
    treasury.withdrawNotAssetDaoERC20(address(randomToken), receiver, 0);
    vm.stopPrank();
  }

  function testWithdrawDaoNative() public {
    // Test: el admin puede retirar saldo nativo del treasury.
    uint256 beforeBalance = nativeReceiver.balance;
    treasury.withdrawDaoNative(nativeReceiver, 2 ether);
    assertEq(nativeReceiver.balance - beforeBalance, 2 ether);
  }

  function testWithdrawDaoNativeRejectsZeroAmount() public {
    // Test: retiro nativo con amount cero debe revertir.
    vm.expectRevert(CommonErrors.ZeroAmount.selector);
    treasury.withdrawDaoNative(nativeReceiver, 0);
  }

  function testViewBalancesAndErc20BalanceZeroTokenRevert() public {
    // Test: nativeBalance/erc20Balance reflejan saldos y erc20Balance valida token no-cero.
    assertEq(treasury.nativeBalance(), 10 ether);
    assertEq(treasury.erc20Balance(address(genesisToken)), 1_000e18);

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    treasury.erc20Balance(address(0));
  }
}
