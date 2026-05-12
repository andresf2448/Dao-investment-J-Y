// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockGuardianStatus {
  mapping(address => bool) private _isActive;

  function setActive(address guardian, bool active) external {
    _isActive[guardian] = active;
  }

  function isActiveGuardian(address guardian) external view returns (bool) {
    return _isActive[guardian];
  }
}
