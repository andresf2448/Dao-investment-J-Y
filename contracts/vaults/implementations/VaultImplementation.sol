// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {IProtocolCore} from "../../interfaces/core/IProtocolCore.sol";
import {IStrategyRouter} from "../../interfaces/execution/IStrategyRouter.sol";
import {IVaultStrategyExecutor} from "../../interfaces/vaults/IVaultStrategyExecutor.sol";
import {CommonErrors} from "../../libraries/errors/CommonErrors.sol";

contract VaultImplementation is
  Initializable,
  ERC20Upgradeable,
  ERC4626Upgradeable,
  AccessControlUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardTransient,
  IVaultStrategyExecutor
{
  using SafeERC20 for IERC20;

  bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
  bytes32 public constant STRATEGY_EXECUTOR_ROLE = keccak256("STRATEGY_EXECUTOR_ROLE");

  address public guardian;
  address public factory;
  address public router;
  address public core;

  event VaultInitialized(
    address indexed asset,
    address indexed guardian,
    address indexed admin,
    address factory,
    address router,
    address core
  );
  event RouterUpdated(address indexed oldRouter, address indexed newRouter);
  event CoreUpdated(address indexed oldCore, address indexed newCore);
  event StrategyExecutionRequest(
    address indexed guardian,
    address indexed adapter,
    bytes data
  );
  event RouterCallExecuted(
    address indexed target,
    uint256 value,
    bytes data,
    bytes result
  );
  event RouterTokenApprovalSet(
    address indexed token,
    address indexed spender,
    uint256 amount
  );

  error VaultImplementation__NotFactory();
  error VaultImplementation__DepositsPaused();
  error VaultImplementation__NotRouter();
  error VaultImplementation__ExternalCallFailed();

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address asset_,
    string memory name_,
    string memory symbol_,
    address guardian_,
    address admin_,
    address factory_,
    address router_,
    address core_
  ) external initializer {
    if(
      asset_ == address(0) ||
      guardian_ == address(0) ||
      admin_ == address(0) ||
      factory_ == address(0) ||
      router_ == address(0) ||
      core_ == address(0)
    ) {
      revert CommonErrors.ZeroAddress();
    }

    if(msg.sender != factory_) revert VaultImplementation__NotFactory();

    __ERC20_init(name_, symbol_);
    __ERC4626_init(IERC20(asset_));
    __AccessControl_init();
    __Pausable_init();

    guardian = guardian_;
    factory = factory_;
    router = router_;
    core = core_;

    _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    _grantRole(GUARDIAN_ROLE, guardian_);
    _grantRole(STRATEGY_EXECUTOR_ROLE, router_);

    emit VaultInitialized(
      asset_,
      guardian_,
      admin_,
      factory_,
      router_,
      core_
    );
  }

  function setRouter(address newRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if(newRouter == address(0)) revert CommonErrors.ZeroAddress();

    address oldRouter = router;
    _revokeRole(STRATEGY_EXECUTOR_ROLE, oldRouter);
    router = newRouter;
    _grantRole(STRATEGY_EXECUTOR_ROLE, newRouter);

    emit RouterUpdated(oldRouter, newRouter);
  }

  function setCore(address newCore) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if(newCore == address(0)) revert CommonErrors.ZeroAddress();

    address oldCore = core;
    core = newCore;

    emit CoreUpdated(oldCore, newCore);
  }

  function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _unpause();
  }

  function deposit(uint256 assets, address receiver)
    public
    override
    whenNotPaused
    nonReentrant
    returns(uint256 shares)
  {
    if(IProtocolCore(core).isVaultDepositsPaused())
      revert VaultImplementation__DepositsPaused();

    return super.deposit(assets, receiver);
  }

  function mint(uint256 shares, address receiver)
    public
    override
    whenNotPaused
    nonReentrant
    returns(uint256 assets)
  {
    if (IProtocolCore(core).isVaultDepositsPaused())
      revert VaultImplementation__DepositsPaused();

    return super.mint(shares, receiver);
  }

  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  )
    public
    override
    whenNotPaused
    nonReentrant
    returns(uint256 shares)
  {
    return super.withdraw(assets, receiver, owner);
  }

  function redeem(
    uint256 shares,
    address receiver,
    address owner
  )
    public
    override
    whenNotPaused
    nonReentrant
    returns(uint256 assets)
  {
    return super.redeem(shares, receiver, owner);
  }

  function executeStrategy(
    address adapter,
    bytes calldata data
  ) external onlyRole(GUARDIAN_ROLE) whenNotPaused {
    if(adapter == address(0)) revert CommonErrors.ZeroAddress();

    emit StrategyExecutionRequest(msg.sender, adapter, data);

    IStrategyRouter(router).execute(
      adapter,
      address(this),
      asset(),
      data
    );
  }

  function executeFromRouter(
    address target,
    uint256 value,
    bytes calldata data
  )
    external
    override
    onlyRole(STRATEGY_EXECUTOR_ROLE)
    returns(bytes memory result)
  {
    if(target == address(0))
      revert CommonErrors.ZeroAddress();

    (bool success, bytes memory returndata) = target.call{value: value}(data);
    if(!success) revert VaultImplementation__ExternalCallFailed();

    emit RouterCallExecuted(target, value, data, returndata);
    return returndata;
  }

  function approveTokenFromRouter(
    address token,
    address spender,
    uint256 amount
  ) external override onlyRole(STRATEGY_EXECUTOR_ROLE) {
    if(token == address(0) || spender == address(0))
      revert CommonErrors.ZeroAddress();

    IERC20(token).forceApprove(spender, amount);
    emit RouterTokenApprovalSet(token, spender, amount);
  }

  function decimals()
    public
    view
    override(ERC20Upgradeable, ERC4626Upgradeable)
    returns(uint8)
  {
    return ERC20Upgradeable.decimals();
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(AccessControlUpgradeable)
    returns(bool)
  {
    return super.supportsInterface(interfaceId);
  }
}