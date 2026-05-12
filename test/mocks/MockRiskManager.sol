// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IRiskManager} from "../../contracts/interfaces/execution/IRiskManager.sol";

contract MockRiskManager is IRiskManager {
  bool public shouldRevert;
  uint256 public validateCalls;
  uint256 public validatedPrice = 1e18;

  error MockRiskManager__ForcedRevert();

  function setShouldRevert(bool value) external {
    shouldRevert = value;
  }

  function setValidatedPrice(uint256 price) external {
    validatedPrice = price;
  }

  function validateExecution(address) external view override {
    if (shouldRevert) revert MockRiskManager__ForcedRevert();
  }

  function getValidatedPrice(address) external view override returns (uint256) {
    return validatedPrice;
  }

  function isAssetHealthy(address) external view override returns (bool) {
    return !shouldRevert && validatedPrice > 0;
  }

  function touchValidate(address asset) external {
    validateCalls++;
    this.validateExecution(asset);
  }
}
