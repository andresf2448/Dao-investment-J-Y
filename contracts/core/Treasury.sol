// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                           IMPORTS
// =============================================================
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IProtocolCore} from "../interfaces/core/IProtocolCore.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title Treasury
/// @notice Custodies protocol funds and controls token/native withdrawals via roles.
/// @dev Genesis-token withdrawals are separated from non-protocol-token sweeping.
contract Treasury is ReentrancyGuardTransient, AccessControl {

  /*//////////////////////////////////////////////////////////////
                              TYPE DECLARATIONS
  //////////////////////////////////////////////////////////////*/
  
  using SafeERC20 for IERC20;
  using Address for address payable;

  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @notice Role allowed to sweep ERC20 tokens that are not DAO-supported assets.
  bytes32 public constant SWEEP_NOT_ASSET_DAO_ROLE = keccak256("SWEEP_NOT_ASSET_DAO_ROLE");

  /// @notice Protocol core used to determine whether a token belongs to DAO-supported assets.
  address public protocolCore;

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when native token is received by treasury.
  event NativeReceived(address indexed sender, uint256 amount);

  /// @notice Emitted when treasury transfers ERC20 tokens out.
  event ERC20Withdrawn(address indexed token, address indexed to, uint256 amount);

  /// @notice Emitted when treasury transfers native token out.
  event NativeWithdrawn(address indexed to, uint256 amount);

  /// @notice Emitted when a generic external call is executed from treasury context.
  event ExternalCallExecuted(address indexed target, uint256 value, bytes data, bytes result);

  /*//////////////////////////////////////////////////////////////
                                  ERRORS
  //////////////////////////////////////////////////////////////*/
  /// @notice Thrown when native withdrawal amount exceeds treasury balance.
  error Treasury__InsufficientNativeBalance();

  /// @notice Thrown when a low-level external call fails.
  error Treasury__CallFailed();

  /// @notice Thrown when token classification does not match requested withdrawal path.
  error Treasury__InvalidToken();

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /// @notice Creates treasury and assigns admin/sweep roles.
  /// @param adminTimelock_ Address receiving default admin role.
  /// @param sweepNotAssetDaoRole_ Address allowed to sweep non-DAO assets.
  constructor(address adminTimelock_, address sweepNotAssetDaoRole_) {
    if (adminTimelock_ == address(0)) revert CommonErrors.ZeroAddress();
    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock_);
    _grantRole(SWEEP_NOT_ASSET_DAO_ROLE, sweepNotAssetDaoRole_);
  }

  // ==========================================================
  //                    RECEIVE / FALLBACK
  // ==========================================================

  /// @notice Receives native token transfers.
  receive() external payable {
    emit NativeReceived(msg.sender, msg.value);
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @notice Sets protocol core dependency used for genesis token validation.
  /// @param protocolcore_ Protocol core contract address.
  function setProtocolCore(address protocolcore_) external onlyRole(DEFAULT_ADMIN_ROLE) {
    protocolCore = protocolcore_;
  }

  /// @notice Withdraws DAO-supported ERC20 assets.
  /// @param token Token to transfer out.
  /// @param to Receiver address.
  /// @param amount Amount to transfer.
  function withdrawDaoERC20(address token, address to, uint256 amount)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
    nonReentrant
  {
    if (!IProtocolCore(protocolCore).hasGenesisToken(token)) {
      revert Treasury__InvalidToken();
    }

    if (token == address(0) || to == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    if (amount == 0) revert CommonErrors.ZeroAmount();

    IERC20(token).safeTransfer(to, amount);

    emit ERC20Withdrawn(token, to, amount);
  }

  /// @notice Sweeps non-DAO ERC20 assets.
  /// @param token Token to transfer out.
  /// @param to Receiver address.
  /// @param amount Amount to transfer.
  function withdrawNotAssetDaoERC20(address token, address to, uint256 amount)
    external
    onlyRole(SWEEP_NOT_ASSET_DAO_ROLE)
    nonReentrant
  {
    if (IProtocolCore(protocolCore).hasGenesisToken(token)) {
      revert Treasury__InvalidToken();
    }

    if (token == address(0) || to == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    if (amount == 0) revert CommonErrors.ZeroAmount();

    IERC20(token).safeTransfer(to, amount);

    emit ERC20Withdrawn(token, to, amount);
  }

  /// @notice Withdraws native token balance.
  /// @param to Receiver of native token.
  /// @param amount Amount to withdraw.
  function withdrawDaoNative(address payable to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
    if (to == address(0)) revert CommonErrors.ZeroAddress();
    if (amount == 0) revert CommonErrors.ZeroAmount();
    if (address(this).balance < amount) {
      revert Treasury__InsufficientNativeBalance();
    }

    to.sendValue(amount);

    emit NativeWithdrawn(to, amount);
  }

  // ==========================================================
  //                            VIEW
  // ==========================================================

  /// @notice Returns current native token balance.
  /// @return Native balance of treasury.
  function nativeBalance() external view returns (uint256) {
    return address(this).balance;
  }

  /// @notice Returns ERC20 balance held by treasury.
  /// @param token Token to query.
  /// @return Token balance of treasury.
  function erc20Balance(address token) external view returns (uint256) {
    if (token == address(0)) revert CommonErrors.ZeroAddress();
    return IERC20(token).balanceOf(address(this));
  }
}
