// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract GovernanceToken is ERC20, EIP712, ERC20Votes, Ownable {
  bool public mintingFinished;

  event MintingFinished();
  error GovernanceToken__MintingDisabled();

  constructor(address initialOwner)
    ERC20("GovernanceToken_J&Y", "GVT")
    EIP712("GovernanceToken_J&Y", "1")
    Ownable(initialOwner)
  {}

  function mint(address to, uint256 amount) external onlyOwner {
    if(mintingFinished) revert GovernanceToken__MintingDisabled();
    _mint(to, amount);
  }

  function finishMinting() external onlyOwner {
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