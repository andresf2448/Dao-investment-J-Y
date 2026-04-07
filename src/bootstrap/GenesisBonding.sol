// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGovernanceToken} from "../interfaces/governance/IGovernanceToken.sol";

contract GenesisBondig is Ownable {
  using SafeERC20 for IERC20;

  IERC20 public immutable purchaseToken;
  IGovernanceToken public immutable governanceToken;
  address public immutable treasury;
  uint256 public immutable rate;
  uint256 public totalPurchased;
  uint256 public totalClaimed;
  bool public finalized;

  mapping(address => uint256) public purchased;
  mapping(address => uint256) public claimed;

  event Purchased(
    address indexed buyer,
    uint256 paymentAmount,
    uint256 governanceAmount
  );

  event Claimed(
    address indexed buyer,
    uint256 governanceAmount
  );

  event Finalized(
    uint256 totalPurchased,
    uint256 totalClaimed
  );

  error GenesisBonding__ZeroAddress();
  error GenesisBonding__ZeroAmount();
  error GenesisBonding__InvalidRate();
  error GenesisBonding__AlreadyFinalized();
  error GenesisBonding__NotFinalized();
  error GenesisBonding__NothingToClaim();

  constructor(
    address initialOwner,
    IERC20 purchaseToken_,
    IGovernanceToken governanceToken_,
    address treasury_,
    uint256 rate_
  ) Ownable(initialOwner) {
    if (initialOwner == address(0)) revert GenesisBonding__ZeroAddress();
    if (address(purchaseToken_) == address(0)) revert GenesisBonding__ZeroAddress();
    if (address(governanceToken_) == address(0)) revert GenesisBonding__ZeroAddress();
    if (treasury_ == address(0)) revert GenesisBonding__ZeroAddress();
    if (rate_ == 0) revert GenesisBonding__InvalidRate();

    purchaseToken = purchaseToken_;
    governanceToken = governanceToken_;
    treasury = treasury_;
    rate = rate_;
  }

  function buy(uint256 paymentAmount) external {
    if (finalized) revert GenesisBonding__AlreadyFinalized();
    if (paymentAmount == 0) revert GenesisBonding__ZeroAmount();

    uint256 governanceTokenAmount = paymentAmount * rate;
    purchased[msg.sender] += governanceTokenAmount;
    totalPurchased += governanceTokenAmount;

    purchaseToken.safeTransferFrom(msg.sender, treasury, paymentAmount);
    emit Purchased(msg.sender, paymentAmount, governanceTokenAmount);
  }

  function finalize() external onlyOwner {
    if (finalized) revert GenesisBonding__AlreadyFinalized();

    finalized = true;
    emit Finalized(totalPurchased, totalClaimed);
  }

  function claim() external {
    if (!finalized) revert GenesisBonding__NotFinalized();

    uint256 purchasedAmount = purchased[msg.sender];
    uint256 alreadyClaimed = claimed[msg.sender];
    uint256 claimable = purchasedAmount - alreadyClaimed;

    if(claimable == 0) revert GenesisBonding__NothingToClaim();

    claimed[msg.sender] = purchasedAmount;
    totalClaimed += claimable;

    governanceToken.mint(msg.sender, claimable);
    emit Claimed(msg.sender, claimable);
  }

  function claimable(address account) external view returns(uint256) {
    if(!finalized){
      return 0;
    }

    return purchased[account] - claimed[account];
  }
}