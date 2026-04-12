// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract GovernanceToken is ERC20, EIP712, ERC20Votes, AccessControl {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bool public mintingFinished;

  event MintingFinished();
  error GovernanceToken__MintingDisabled();

  constructor(address admin)
    ERC20("GovernanceToken_J&Y", "GVT")
    EIP712("GovernanceToken_J&Y", "1")
    AccessControl()
  {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
  }

  function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
    if(mintingFinished) revert GovernanceToken__MintingDisabled();
    _mint(to, amount);
  }

  function finishMinting() external onlyRole(MINTER_ROLE) {
    mintingFinished = true;
    emit MintingFinished();
  }
 
  function _update(address from, address to, uint256 value)
    internal
    override(ERC20, ERC20Votes)
  {
    super._update(from, to, value);
  }
}