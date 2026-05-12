// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {GovernanceToken } from "../../contracts/governance/GovernanceToken.sol";
import {Test, console} from "forge-std/Test.sol";

contract GovernaceTokenTest is Test{
  address public adminTimeLock = makeAddr("adminTimelock");
  address public userRoleMinter = makeAddr('USER_MINTER');
  address public userTOMintBalance = makeAddr('USER_TO_MINT');
  uint256 public AMOUNT_MINT = 1_000e18;

  event MintingFinished();

  GovernanceToken governanceToken;
  function setUp() public {
    governanceToken = new GovernanceToken(adminTimeLock);
  }

  function testMintWithValidRoleMinter() public {
    _createRoleMinter();

    vm.prank(userRoleMinter);
      governanceToken.mint(userTOMintBalance, AMOUNT_MINT);

    uint256 balanceUser = governanceToken.balanceOf(userTOMintBalance);
    assertEq(balanceUser, AMOUNT_MINT);
  }

  function testRevertWithInvalidRoleMinter() public {
    vm.expectRevert();

    vm.prank(userRoleMinter);
      governanceToken.mint(userTOMintBalance, AMOUNT_MINT);
  }

  function testFinishMintingIsfalse() public view {
    assertFalse(governanceToken.isMintingFinished());
  }

  function testExpectIsMintingCanBeChangeByMinterRole() public {
    _createRoleMinter();

    vm.prank(userRoleMinter);
      governanceToken.finishMinting();

    assertTrue(governanceToken.isMintingFinished());
  }

  function testCheckEmitWhenFinishMintingIsCalled() public {
    _createRoleMinter();

    vm.expectEmit(false, false, false, false);
    emit MintingFinished();

    vm.prank(userRoleMinter);
      governanceToken.finishMinting();
  }

  function _createRoleMinter() private {
    vm.startPrank(adminTimeLock);
      governanceToken.grantRole(
          governanceToken.MINTER_ROLE(),
          userRoleMinter
      );
    vm.stopPrank();
  }
}