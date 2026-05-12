// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ProtocolCore} from "../../../contracts/core/ProtocolCore.sol";
import {TimeLock} from "../../../contracts/governance/TimeLock.sol";
import {CommonErrors} from "../../../contracts/libraries/errors/CommonErrors.sol";

contract ProtocolCoreUnitTest is Test {
  ProtocolCore internal core;
  TimeLock internal timelock;

  address internal emergency = makeAddr("emergency");
  address internal outsider = makeAddr("outsider");
  address internal assetA = makeAddr("assetA");
  address internal assetB = makeAddr("assetB");

  function setUp() public {
    address[] memory proposers = new address[](0);
    address[] memory executors = new address[](0);
    timelock = new TimeLock(2 days, proposers, executors, address(this));

    address[] memory genesis = new address[](2);
    genesis[0] = assetA;
    genesis[1] = address(0);

    ProtocolCore impl = new ProtocolCore();
    core = ProtocolCore(
      address(
        new ERC1967Proxy(
          address(impl), abi.encodeCall(ProtocolCore.initialize, (payable(address(timelock)), emergency, genesis, assetA))
        )
      )
    );
  }

  function testInitializeRejectsZeroCriticalAddresses() public {
    // Test: initialize debe revertir cuando alguna dirección crítica es cero.
    ProtocolCore impl = new ProtocolCore();

    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    new ERC1967Proxy(
      address(impl), abi.encodeCall(ProtocolCore.initialize, (payable(address(0)), emergency, new address[](0), assetA))
    );
  }

  function testSetSupportedVaultAssetRoleAndZeroChecks() public {
    // Test: solo manager puede setear assets y no acepta asset cero.
    vm.prank(outsider);
    vm.expectRevert();
    core.setSupportedVaultAsset(assetB, true);

    vm.prank(address(timelock));
    core.setSupportedVaultAsset(assetB, true);
    assertTrue(core.isVaultAssetSupported(assetB));

    vm.prank(address(timelock));
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    core.setSupportedVaultAsset(address(0), true);
  }

  function testPauseAndUnpauseRoles() public {
    // Test: emergency pausa; manager despausa; outsider revierte.
    vm.prank(outsider);
    vm.expectRevert();
    core.pauseVaultCreation();

    vm.prank(emergency);
    core.pauseVaultCreation();
    assertTrue(core.isVaultCreationPaused());

    vm.prank(address(timelock));
    core.unpauseVaultCreation();
    assertFalse(core.isVaultCreationPaused());

    vm.prank(emergency);
    core.pauseVaultDeposits();
    assertTrue(core.isVaultDepositsPaused());

    vm.prank(address(timelock));
    core.unpauseVaultDeposits();
    assertFalse(core.isVaultDepositsPaused());
  }

  function testSupportedGenesisTokensAppendAndIgnoreZeroAddress() public {
    // Test: setSupportedGenesisTokens agrega valores nuevos e ignora address(0).
    address[] memory next = new address[](3);
    next[0] = assetB;
    next[1] = address(0);
    next[2] = assetA;

    vm.prank(address(timelock));
    core.setSupportedGenesisTokens(next);

    assertTrue(core.hasGenesisToken(assetA));
    assertTrue(core.hasGenesisToken(assetB));
    assertFalse(core.hasGenesisToken(address(0)));
  }

  function testWithdrawNativeValidationsAndSuccess() public {
    // Test: withdrawNative valida parámetros y transfiere correctamente.
    vm.deal(address(core), 2 ether);

    vm.prank(address(timelock));
    vm.expectRevert(CommonErrors.ZeroAddress.selector);
    core.withdrawNative(payable(address(0)), 1 ether);

    vm.prank(address(timelock));
    vm.expectRevert(CommonErrors.ZeroAmount.selector);
    core.withdrawNative(payable(outsider), 0);

    vm.prank(address(timelock));
    vm.expectRevert(ProtocolCore.ProtocolCore__InsufficientNativeBalance.selector);
    core.withdrawNative(payable(outsider), 3 ether);

    uint256 before = outsider.balance;
    vm.prank(address(timelock));
    core.withdrawNative(payable(outsider), 1 ether);
    assertEq(outsider.balance, before + 1 ether);
  }

  function testGetTimelockMinDelay() public view {
    // Test: getTimelockMinDelay retorna el min delay del timelock configurado.
    assertEq(core.getTimelockMinDelay(), 2 days);
  }
}
