// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IProtocolCore} from "../interfaces/core/IProtocolCore.sol";

contract Treasury is ReentrancyGuardTransient, AccessControl {
  using SafeERC20 for IERC20;
  using Address for address payable;

  bytes32 public constant SWEEP_NOT_ASSET_DAO_ROLE = keccak256('SWEEP_NOT_ASSET_DAO_ROLE');
  address public protocolCore;
  mapping(address token => uint256 balance) public sweepBalanceTokens;

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
  error Treasury__InvalidToken();

  constructor(address adminTimelock_, address sweepNotAssetDaoRole_) {
    if(adminTimelock_ == address(0)) revert CommonErrors.ZeroAddress();
    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock_);
    _grantRole(SWEEP_NOT_ASSET_DAO_ROLE, sweepNotAssetDaoRole_);
  }

  receive() external payable {
    emit NativeReceived(msg.sender, msg.value);
  }

  function setProtocolCore(address protocolcore_)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    protocolCore = protocolcore_;
  }

  function withdrawDaoERC20(
    address token,
    address to,
    uint256 amount
  ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
    if(!IProtocolCore(protocolCore).hasGenesisToken(token))
      revert Treasury__InvalidToken();

    if (token == address(0) || to == address(0))
      revert CommonErrors.ZeroAddress();

    if (amount == 0) revert CommonErrors.ZeroAmount();

    IERC20(token).safeTransfer(to, amount);

    emit ERC20Withdrawn(token, to, amount);
  }

  function withdrawNotAssetDaoERC20(
    address token,
    address to,
    uint256 amount
  )
    external
    onlyRole(SWEEP_NOT_ASSET_DAO_ROLE)
    nonReentrant
  {
    if(IProtocolCore(protocolCore).hasGenesisToken(token))
      revert Treasury__InvalidToken();

    if (token == address(0) || to == address(0))
      revert CommonErrors.ZeroAddress();
    
    if (amount == 0) revert CommonErrors.ZeroAmount();

    IERC20(token).safeTransfer(to, amount);

    emit ERC20Withdrawn(token, to, amount);
  }

  function withdrawDaoNative(
    address payable to,
    uint256 amount
  ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
    if (to == address(0)) revert CommonErrors.ZeroAddress();
    if (amount == 0) revert CommonErrors.ZeroAmount();
    if (address(this).balance < amount) {
      revert Treasury__InsufficientNativeBalance();
    }

    to.sendValue(amount);

    emit NativeWithdrawn(to, amount);
  }

  // function execute(
  //   address target,
  //   uint256 value,
  //   bytes calldata data
  // )
  //   external
  //   onlyRole(DEFAULT_ADMIN_ROLE)
  //   nonReentrant
  //   returns(bytes memory result)
  // {
  //   if (target == address(0)) revert CommonErrors.ZeroAddress();

  //   (bool success, bytes memory returndata) = target.call{value: value}(data);
  //   if(!success) revert Treasury__CallFailed();

  //   emit ExternalCallExecuted(target, value, data, returndata);
  //   return returndata;
  // }

  function nativeBalance() external view returns(uint256) {
    return address(this).balance;
  }

  function erc20Balance(address token) external view returns(uint256) {
    if(token == address(0)) revert CommonErrors.ZeroAddress();
    return IERC20(token).balanceOf(address(this));
  }
}