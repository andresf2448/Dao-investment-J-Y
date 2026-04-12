// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGovernanceToken} from "../interfaces/governance/IGovernanceToken.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract GenesisBonding is AccessControl, ReentrancyGuardTransient {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet private purchaseTokens;

  bytes32 public constant SWEEP_ROLE = keccak256('SWEEP_ROLE');

  IGovernanceToken public immutable governanceToken;
  address public immutable treasury;
  uint256 public immutable rate;
  uint256 public totalGovernanceTokenPurchased;
  bool public isFinalized;

  event Finalized(
    uint256 totalGovernanceTokenPurchased
  );
  event Purchased(
    address indexed buyer,
    uint256 paymentAmount,
    uint256 governanceAmount
  );
  event Swept(
    address indexed token,
    uint256 amount
  );

  error GenesisBonding__InvalidRate();
  error GenesisBonding__AlreadyFinalized();
  error GenesisBonding__TokenNotAllowedToSweep();
  error GenesisBonding__InvalidToken();

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

  function sweep(address token) external onlyRole(SWEEP_ROLE) {
    if (purchaseTokens.contains(token) || token == address(governanceToken)) 
      revert GenesisBonding__TokenNotAllowedToSweep();

    if (token == address(0)) revert CommonErrors.ZeroAddress();

    uint256 balance = IERC20(token).balanceOf(address(this));

    if (balance > 0) {
      IERC20(token).safeTransfer(treasury, balance);

      emit Swept(token, balance);
    }
  }

  function buy(address token, uint256 paymentAmount) external nonReentrant {
    if (isFinalized) revert GenesisBonding__AlreadyFinalized();
    if (paymentAmount == 0) revert CommonErrors.ZeroAmount();
    if (token == address(0)) revert CommonErrors.ZeroAddress();
    if (!purchaseTokens.contains(token))
      revert GenesisBonding__InvalidToken();

    uint256 governanceTokenAmount = paymentAmount * rate;
    totalGovernanceTokenPurchased += governanceTokenAmount;

    IERC20(token).safeTransferFrom(msg.sender, treasury, paymentAmount);
    governanceToken.mint(msg.sender, governanceTokenAmount);

    emit Purchased(msg.sender, paymentAmount, governanceTokenAmount);
  }

  function finalize() external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (isFinalized) revert GenesisBonding__AlreadyFinalized();

    bytes32 minterRole;
    assembly {
      let ptr := mload(0x40)
      //0x4d494e5445525f524f4c45000000000000000000000000000000000000000000 (means MINTER_CODE in hex)
      mstore(ptr, 0x4d494e5445525f524f4c45000000000000000000000000000000000000000000)
      minterRole := keccak256(ptr, 11)
    }

    isFinalized = true;
    governanceToken.finishMinting();
    governanceToken.renounceRole(minterRole, address(this));

    emit Finalized(totalGovernanceTokenPurchased);
  }

  function setPurchaseTokens(address[] memory allowedGenesisTokens) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setPurchaseTokens(allowedGenesisTokens);
  }

  function _setPurchaseTokens(address[] memory allowedGenesisTokens) private {
    uint256 length = allowedGenesisTokens.length;

    for (uint256 i = 0; i < length; i++) {
      if (allowedGenesisTokens[i] == address(0)) revert CommonErrors.ZeroAddress();

      purchaseTokens.add(allowedGenesisTokens[i]);
    }
  }
}