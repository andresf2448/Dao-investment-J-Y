// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                           IMPORTS
// =============================================================
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGovernanceToken} from "../interfaces/governance/IGovernanceToken.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title GenesisBonding
/// @notice Bootstrap contract that swaps approved payment tokens for governance tokens at a fixed rate.
/// @dev Funds are forwarded to treasury and minting is disabled once finalize is executed by admin.
contract GenesisBonding is AccessControl, ReentrancyGuardTransient {

  /*//////////////////////////////////////////////////////////////
                              TYPE DECLARATIONS
  //////////////////////////////////////////////////////////////*/
  
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @dev Set of ERC20 tokens accepted as payment in genesis phase.
  EnumerableSet.AddressSet private purchaseTokens;

  /// @notice Role allowed to sweep non-protocol tokens to treasury.
  bytes32 public constant SWEEP_ROLE = keccak256("SWEEP_ROLE");

  /// @notice Governance token minted to buyers.
  IGovernanceToken public immutable governanceToken;

  /// @notice Treasury that receives payment tokens and sweep transfers.
  address public immutable treasury;

  /// @notice Fixed conversion rate from payment token units to governance token units.
  uint256 public immutable rate;

  /// @notice Total governance tokens minted through purchases.
  uint256 public totalGovernanceTokenPurchased;

  /// @notice Indicates whether the genesis sale has been finalized.
  bool public isFinalized;

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when genesis sale is finalized and minting is closed.
  event Finalized(uint256 totalGovernanceTokenPurchased);

  /// @notice Emitted when a buyer purchases governance tokens.
  event Purchased(address indexed buyer, uint256 paymentAmount, uint256 governanceAmount);

  /// @notice Emitted when a non-protocol token is swept to treasury.
  event Swept(address indexed token, uint256 amount);

  /*//////////////////////////////////////////////////////////////
                                  ERRORS
  //////////////////////////////////////////////////////////////*/
  /// @notice Thrown when rate is configured as zero.
  error GenesisBonding__InvalidRate();

  /// @notice Thrown when an operation requires a non-finalized state.
  error GenesisBonding__AlreadyFinalized();

  /// @notice Thrown when trying to sweep an accepted purchase token or governance token.
  error GenesisBonding__TokenNotAllowedToSweep();
  
  /// @notice Thrown when purchase token is not in the allowlist.
  error GenesisBonding__InvalidToken();

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /// @notice Initializes genesis bonding with accepted tokens, treasury, and mint rate.
  /// @param adminTimelock Address receiving default admin role.
  /// @param sweepRole Address receiving sweep permissions.
  /// @param allowedGenesisTokens Initial list of accepted payment tokens.
  /// @param governanceToken_ Governance token to mint for buyers.
  /// @param treasury_ Treasury receiving payments and swept balances.
  /// @param rate_ Conversion rate from payment units to governance token units.
  constructor(
    address adminTimelock,
    address sweepRole,
    address[] memory allowedGenesisTokens,
    IGovernanceToken governanceToken_,
    address treasury_,
    uint256 rate_
  ) {
    if (adminTimelock == address(0)) revert CommonErrors.ZeroAddress();
    if (sweepRole == address(0)) revert CommonErrors.ZeroAddress();
    if (address(governanceToken_) == address(0)) revert CommonErrors.ZeroAddress();
    if (treasury_ == address(0)) revert CommonErrors.ZeroAddress();
    if (rate_ == 0) revert GenesisBonding__InvalidRate();
    _setPurchaseTokens(allowedGenesisTokens);

    governanceToken = governanceToken_;
    treasury = treasury_;
    rate = rate_;

    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock);
    _grantRole(SWEEP_ROLE, sweepRole);
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @notice Sweeps non-protocol tokens accidentally sent to this contract into treasury.
  /// @param token Token to sweep.
  function sweep(address token) external onlyRole(SWEEP_ROLE) {
    if (purchaseTokens.contains(token) || token == address(governanceToken)) {
      revert GenesisBonding__TokenNotAllowedToSweep();
    }

    if (token == address(0)) revert CommonErrors.ZeroAddress();

    uint256 balance = IERC20(token).balanceOf(address(this));

    if (balance > 0) {
      IERC20(token).safeTransfer(treasury, balance);

      emit Swept(token, balance);
    }
  }

  /// @notice Purchases governance tokens using an approved bootstrap token.
  /// @param token Accepted payment token.
  /// @param paymentAmount Amount of payment token transferred to treasury.
  function buy(address token, uint256 paymentAmount) external nonReentrant {
    if (isFinalized) revert GenesisBonding__AlreadyFinalized();
    if (paymentAmount == 0) revert CommonErrors.ZeroAmount();
    if (token == address(0)) revert CommonErrors.ZeroAddress();
    if (!purchaseTokens.contains(token)) {
      revert GenesisBonding__InvalidToken();
    }

    uint256 governanceTokenAmount = paymentAmount * rate;
    totalGovernanceTokenPurchased += governanceTokenAmount;

    IERC20(token).safeTransferFrom(msg.sender, treasury, paymentAmount);
    governanceToken.mint(msg.sender, governanceTokenAmount);

    emit Purchased(msg.sender, paymentAmount, governanceTokenAmount);
  }

  /// @notice Finalizes genesis phase, ends minting, and relinquishes minter role.
  function finalize() external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (isFinalized) revert GenesisBonding__AlreadyFinalized();

    bytes32 minterRole;
    assembly {
      let ptr := mload(0x40)
      // 0x4d494e5445525f524f4c45 = "MINTER_ROLE" (11 bytes)
      mstore(ptr, 0x4d494e5445525f524f4c45000000000000000000000000000000000000000000)
      minterRole := keccak256(ptr, 11)
    }

    isFinalized = true;
    governanceToken.finishMinting();
    governanceToken.renounceRole(minterRole, address(this));

    emit Finalized(totalGovernanceTokenPurchased);
  }

  /// @notice Adds tokens to the accepted purchase token set.
  /// @param allowedGenesisTokens Token addresses to allow for purchases.
  function setPurchaseTokens(address[] memory allowedGenesisTokens) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setPurchaseTokens(allowedGenesisTokens);
  }

  // ==========================================================
  //                           PRIVATE
  // ==========================================================

  /// @dev Adds non-zero tokens to internal accepted-token set.
  /// @param allowedGenesisTokens Token list to append.
  function _setPurchaseTokens(address[] memory allowedGenesisTokens) private {
    uint256 length = allowedGenesisTokens.length;

    for (uint256 i = 0; i < length; i++) {
      if (allowedGenesisTokens[i] == address(0)) revert CommonErrors.ZeroAddress();

      purchaseTokens.add(allowedGenesisTokens[i]);
    }
  }
}
