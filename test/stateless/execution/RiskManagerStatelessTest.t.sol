// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {RiskManager} from "../../../contracts/execution/RiskManager.sol";
import {MockV3AggregatorControlled} from "../../mocks/MockV3AggregatorControlled.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RiskManagerStatelessTest is Test {
  RiskManager internal riskManager;
  MockV3AggregatorControlled internal feed;

  address internal asset = makeAddr("asset");

  function setUp() public {
    RiskManager implementation = new RiskManager();
    riskManager = RiskManager(
      address(new ERC1967Proxy(address(implementation), abi.encodeCall(RiskManager.initialize, (address(this), address(this)))))
    );

    feed = new MockV3AggregatorControlled(8, 1e8);
  }

  function testFuzzValidatedPriceNormalization(uint8 feedDecimals, uint256 rawAnswer) public {
    // Test: getValidatedPrice normaliza correctamente para decimals <, = o > 18.
    uint8 decimals = uint8(bound(feedDecimals, 6, 24));
    uint256 answer = bound(rawAnswer, 1, 1e18);

    feed.setData(decimals, int256(answer), 1, 1, block.timestamp);
    riskManager.setAssetConfig(asset, address(feed), 1 days, false, 0, 0, true);

    uint256 expected;
    if (decimals == 18) {
      expected = answer;
    } else if (decimals < 18) {
      expected = answer * (10 ** (18 - decimals));
    } else {
      expected = answer / (10 ** (decimals - 18));
    }

    if (expected == 0) {
      vm.expectRevert(RiskManager.RiskManager__InvalidPrice.selector);
      riskManager.getValidatedPrice(asset);
      return;
    }

    uint256 actual = riskManager.getValidatedPrice(asset);
    assertEq(actual, expected);
  }

  function testValidateExecutionRevertsForStalePrice() public {
    // Test: validateExecution revierte si el precio está stale según heartbeat.
    vm.warp(10 days);
    feed.setData(8, 1e8, 1, 1, block.timestamp - 2 days);
    riskManager.setAssetConfig(asset, address(feed), 1 days, false, 0, 0, true);

    vm.expectRevert(RiskManager.RiskManager__StalePrice.selector);
    riskManager.validateExecution(asset);
  }

  function testValidateExecutionRevertsForInvalidRound() public {
    // Test: validateExecution revierte cuando answeredInRound < roundId.
    feed.setData(8, 1e8, 2, 1, block.timestamp);
    riskManager.setAssetConfig(asset, address(feed), 1 days, false, 0, 0, true);

    vm.expectRevert(RiskManager.RiskManager__InvalidRound.selector);
    riskManager.validateExecution(asset);
  }

  function testIsAssetHealthyReturnsFalseWhenExecutionPaused() public {
    // Test: isAssetHealthy devuelve false (sin revertir) si execution está pausada.
    feed.setData(8, 1e8, 1, 1, block.timestamp);
    riskManager.setAssetConfig(asset, address(feed), 1 days, false, 0, 0, true);

    riskManager.pauseAdapterExecution();

    assertFalse(riskManager.isAssetHealthy(asset));
  }
}
