// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGovernanceToken} from "../interfaces/governance/IGovernanceToken.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract GenesisBonding is Ownable, ReentrancyGuardTransient {
  using SafeERC20 for IERC20;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  IERC20 public immutable purchaseToken;
  IGovernanceToken public immutable governanceToken;
  address public immutable treasury;
  uint256 public immutable rate;
  uint256 public totalGovernanceTokenPurchased;
  bool public finalized;

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

  constructor(
    address adminTimelock,
    IERC20 purchaseToken_,
    IGovernanceToken governanceToken_,
    address treasury_,
    uint256 rate_
  ) Ownable(adminTimelock) {
    if (adminTimelock == address(0)) revert CommonErrors.ZeroAddress();
    if (address(purchaseToken_) == address(0)) revert CommonErrors.ZeroAddress();
    if (address(governanceToken_) == address(0)) revert CommonErrors.ZeroAddress();
    if (treasury_ == address(0)) revert CommonErrors.ZeroAddress();
    if (rate_ == 0) revert GenesisBonding__InvalidRate();

    purchaseToken = purchaseToken_;
    governanceToken = governanceToken_;
    treasury = treasury_;
    rate = rate_;
  }

  function sweep(address token) external onlyOwner {
    if (token == address(0)) revert CommonErrors.ZeroAddress();

    uint256 balance = IERC20(token).balanceOf(address(this));
    if (balance > 0) {
      IERC20(token).safeTransfer(treasury, balance);

      emit Swept(token, balance);
    }
  }

  function buy(uint256 paymentAmount) external nonReentrant {
    if (finalized) revert GenesisBonding__AlreadyFinalized();
    if (paymentAmount == 0) revert CommonErrors.ZeroAmount();

    uint256 governanceTokenAmount = paymentAmount * rate;
    totalGovernanceTokenPurchased += governanceTokenAmount;

    purchaseToken.safeTransferFrom(msg.sender, treasury, paymentAmount);
    governanceToken.mint(msg.sender, governanceTokenAmount);

    emit Purchased(msg.sender, paymentAmount, governanceTokenAmount);
  }

  function finalize() external onlyOwner {
    if (finalized) revert GenesisBonding__AlreadyFinalized();

    finalized = true;
    governanceToken.finishMinting();
    governanceToken.renounceRole(MINTER_ROLE, address(this));

    emit Finalized(totalGovernanceTokenPurchased);
  }
}