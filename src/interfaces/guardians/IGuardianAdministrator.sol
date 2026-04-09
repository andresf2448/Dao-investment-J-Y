// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IGuardianAdministrator {
  function isActiveGuardian(address guardian) external view returns(bool);
}