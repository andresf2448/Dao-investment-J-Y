// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IVault {
  function initialize(
    address asset_,
    string memory name_,
    string memory symbol_,
    address guardian_,
    address admin_,
    address factory_,
    address router_,
    address core_
  ) external;
}
