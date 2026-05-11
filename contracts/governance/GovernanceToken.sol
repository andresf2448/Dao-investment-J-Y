// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// =============================================================
//                           IMPORTS
// =============================================================
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/**
 * @title GovernanceToken
 * @notice ERC20 token with voting capabilities for the DAO governance system.
 * @dev Implements ERC20, ERC20Votes (for voting power delegation), EIP712 (for typed signatures),
 *      and AccessControl (for role-based access control). Token minting is controlled via MINTER_ROLE.
 *      Minting can be finished by calling finishMinting() which locks further minting.
 */
contract GovernanceToken is ERC20, EIP712, ERC20Votes, AccessControl {
  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @notice Role required to mint new tokens
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  /// @notice Flag indicating if minting has been finished
  bool public isMintingFinished;

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when minting is finished
  event MintingFinished();

  /*//////////////////////////////////////////////////////////////
                                  ERRORS
  //////////////////////////////////////////////////////////////*/
  /// @notice Error thrown when attempting to mint after minting is finished
  error GovernanceToken__MintingDisabled();

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /**
   * @notice Constructor initializes the token with name, symbol, and sets admin timelock as default admin
   * @param adminTimelock Address that will be granted DEFAULT_ADMIN_ROLE
   */
  constructor(address adminTimelock) ERC20("GovernanceToken_J&Y", "GVT") EIP712("GovernanceToken_J&Y", "1") AccessControl() {
    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock);
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /**
   * @notice Mints new tokens to a specified address
   * @dev Only callable by accounts with MINTER_ROLE. Reverts if minting has been finished.
   * @param to Address to receive the minted tokens
   * @param amount Amount of tokens to mint
   */
  function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
    if (isMintingFinished) revert GovernanceToken__MintingDisabled();
    _mint(to, amount);
  }

  /**
   * @notice Finishes the minting process, preventing any further token creation
   * @dev Only callable by accounts with MINTER_ROLE. Sets isMintingFinished to true and emits MintingFinished event.
   */
  function finishMinting() external onlyRole(MINTER_ROLE) {
    isMintingFinished = true;
    emit MintingFinished();
  }

  // ==========================================================
  //                          INTERNAL
  // ==========================================================

  /**
   * @notice Internal update hook that is called on transfers, approvals, etc.
   * @dev Overrides ERC20 and ERC20Votes to call super implementations
   * @param from Address the tokens are transferred from
   * @param to Address the tokens are transferred to
   * @param value Amount of tokens being transferred
   */
  function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
    super._update(from, to, value);
  }
}
