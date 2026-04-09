// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";

contract Treasury is ReentrancyGuardTransient {
  using SafeERC20 for IERC20;
  using Address for address payable;

  address public immutable adminTimelock;

  event NativeReceived(address indexed sender, uint256 amount);

  event ERC20Withdrawn(
    address indexed token,
    address indexed to,
    uint256 amount
  );

  event NativeWithdrawn(
    address indexed to,
    uint256 amount
  );

  event ExternalCallExecuted(
    address indexed target,
    uint256 value,
    bytes data,
    bytes result
  );

  error Treasury__InsufficientNativeBalance();
  error Treasury__CallFailed();

  modifier onlyTimelock() {
    if(msg.sender != adminTimelock) revert CommonErrors.Unauthorized();
    _;
  }

  constructor(address adminTimelock_) {
    if(adminTimelock_ == address(0)) revert CommonErrors.ZeroAddress();
    adminTimelock = adminTimelock_;
  }

  receive() external payable {
    emit NativeReceived(msg.sender, msg.value);
  }

  function withdrawERC20(
    address token,
    address to,
    uint256 amount
  ) external onlyTimelock nonReentrant {
    if (token == address(0) || to == address(0)) {
      revert CommonErrors.ZeroAddress();
    }
    if (amount == 0) revert CommonErrors.ZeroAmount();

    IERC20(token).safeTransfer(to, amount);

    emit ERC20Withdrawn(token, to, amount);
  }

  function withdrawNative(
    address payable to,
    uint256 amount
  ) external onlyTimelock nonReentrant {
    if (to == address(0)) revert CommonErrors.ZeroAddress();
    if (amount == 0) revert CommonErrors.ZeroAmount();
    if (address(this).balance < amount) {
      revert Treasury__InsufficientNativeBalance();
    }

    to.sendValue(amount);

    emit NativeWithdrawn(to, amount);
  }

  function execute(
    address target,
    uint256 value,
    bytes calldata data
  )
    external
    onlyTimelock
    nonReentrant
    returns(bytes memory result)
  {
    if (target == address(0)) revert CommonErrors.ZeroAddress();

    (bool success, bytes memory returndata) = target.call{value: value}(data);
    if(!success) revert Treasury__CallFailed();

    emit ExternalCallExecuted(target, value, data, returndata);
    return returndata;
  }

  function nativeBalance() external view returns(uint256) {
    return address(this).balance;
  }

  function erc20Balance(address token) external view returns(uint256) {
    if(token == address(0)) revert CommonErrors.ZeroAddress();
    return IERC20(token).balanceOf(address(this));
  }
}