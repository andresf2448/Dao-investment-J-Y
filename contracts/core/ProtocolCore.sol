// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// =============================================================
//                           IMPORTS
// =============================================================
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title ProtocolCore
/// @notice Central protocol configuration for supported assets/tokens and pause flags.
/// @dev Upgradeable UUPS core with manager/emergency role split.
contract ProtocolCore is Initializable, AccessControlUpgradeable, UUPSUpgradeable {

  /*//////////////////////////////////////////////////////////////
                              TYPE DECLARATIONS
  //////////////////////////////////////////////////////////////*/
  
  using EnumerableSet for EnumerableSet.AddressSet;
  using Address for address payable;

  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @notice Role allowed to manage supported assets and genesis-token list.
  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

  /// @notice Role allowed to trigger emergency pause actions.
  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

  /// @dev Asset support map used by factory during vault creation.
  mapping(address => bool) private _supportedVaultAssets;

  /// @dev Set of accepted genesis-phase payment tokens.
  EnumerableSet.AddressSet private _supportedGenesisTokens;

  /// @notice Global flag to pause new vault creation.
  bool public isVaultCreationPaused;

  /// @notice Global flag to pause vault user deposits.
  bool public isVaultDepositsPaused;

  /// @dev Timelock address used for governance delay queries.
  address payable private adminTimelock;

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when a vault asset support flag is changed.
  event SupportedVaultAssetSet(address indexed asset, bool allowed);

  /// @notice Emitted when vault creation pause flag changes.
  event VaultCreationPauseSet(bool paused);

  /// @notice Emitted when vault deposit pause flag changes.
  event VaultDepositsPauseSet(bool paused);

  /// @notice Emitted when native ether is received by the contract.
  event NativeReceived(address indexed sender, uint256 amount);

  /// @notice Emitted when native ether is withdrawn by admin.
  event NativeWithdrawn(address indexed to, uint256 amount);

  /// @notice Emitted when supported genesis tokens are updated.
  event SupportedGenesisTokensSet(address[] tokens);

  /// @notice Thrown when contract native balance is insufficient for withdrawal.
  error ProtocolCore__InsufficientNativeBalance();

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  // ==========================================================
  //                      CONSTRUCTOR
  // ==========================================================

  /// @dev Locks implementation contract by disabling initializer calls.
  constructor() {
    _disableInitializers();
  }

  /// @notice Withdraws native token balance from the contract.
  /// @param to Recipient address.
  /// @param amount Amount of native token to withdraw.
  function withdrawNative(address payable to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (to == address(0)) revert CommonErrors.ZeroAddress();
    if (amount == 0) revert CommonErrors.ZeroAmount();
    if (address(this).balance < amount) revert ProtocolCore__InsufficientNativeBalance();

    to.sendValue(amount);
    emit NativeWithdrawn(to, amount);
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @notice Initializes protocol roles and initial supported assets.
  /// @param adminTimelock_ Admin and manager role address.
  /// @param emergencyOperator Emergency role address.
  /// @param allowedGenesisTokens Initial list of accepted genesis tokens.
  /// @param allowedVaultToken Initial vault asset to support.
  function initialize(
    address payable adminTimelock_,
    address emergencyOperator,
    address[] memory allowedGenesisTokens,
    address allowedVaultToken
  ) external initializer {
    if (adminTimelock_ == address(0) || emergencyOperator == address(0) || allowedVaultToken == address(0)) {
      revert CommonErrors.ZeroAddress();
    }
    __AccessControl_init();

    adminTimelock = adminTimelock_;
    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock_);
    _grantRole(MANAGER_ROLE, adminTimelock_);
    _grantRole(EMERGENCY_ROLE, emergencyOperator);

    _setSupportedGenesisTokens(allowedGenesisTokens);
    _setSupportedVaultToken(allowedVaultToken, true);
  }

  /// @notice Adds/removes a vault asset support flag.
  /// @param asset Vault underlying asset.
  /// @param allowed True to allow vault creation for this asset.
  function setSupportedVaultAsset(address asset, bool allowed) external onlyRole(MANAGER_ROLE) {
    _setSupportedVaultToken(asset, allowed);
  }

  /// @notice Checks if an asset is allowed for vault creation.
  /// @param asset Asset address to query.
  /// @return True if asset is supported.
  function isVaultAssetSupported(address asset) external view returns (bool) {
    return _supportedVaultAssets[asset];
  }

  /// @notice Pauses vault creation actions.
  function pauseVaultCreation() external onlyRole(EMERGENCY_ROLE) {
    isVaultCreationPaused = true;
    emit VaultCreationPauseSet(true);
  }

  /// @notice Pauses user deposits into vaults.
  function pauseVaultDeposits() external onlyRole(EMERGENCY_ROLE) {
    isVaultDepositsPaused = true;
    emit VaultDepositsPauseSet(true);
  }

  /// @notice Unpauses vault creation.
  function unpauseVaultCreation() external onlyRole(MANAGER_ROLE) {
    isVaultCreationPaused = false;
    emit VaultCreationPauseSet(false);
  }

  /// @notice Unpauses user deposits into vaults.
  function unpauseVaultDeposits() external onlyRole(MANAGER_ROLE) {
    isVaultDepositsPaused = false;
    emit VaultDepositsPauseSet(false);
  }

  /// @notice Checks whether a token is listed as a genesis token.
  /// @param token Token address to query.
  /// @return True if token is included.
  function hasGenesisToken(address token) external view returns (bool) {
    return _supportedGenesisTokens.contains(token);
  }

  /// @notice Returns all configured genesis tokens.
  /// @return Token list currently marked as supported genesis tokens.
  function getSupportedGenesisTokens() external view returns (address[] memory) {
    return _supportedGenesisTokens.values();
  }

  /// @notice Reads current timelock minimum delay.
  /// @return Minimum delay in seconds from timelock controller.
  function getTimelockMinDelay() external view returns (uint256) {
    return TimelockController(adminTimelock).getMinDelay();
  }

  // ==========================================================
  //                           PUBLIC
  // ==========================================================

  /// @notice Adds tokens to supported genesis set.
  /// @param allowedGenesisTokens Tokens to include.
  function setSupportedGenesisTokens(address[] memory allowedGenesisTokens) public onlyRole(MANAGER_ROLE) {
    _setSupportedGenesisTokens(allowedGenesisTokens);
    emit SupportedGenesisTokensSet(allowedGenesisTokens);
  }

  // ==========================================================
  //                          INTERNAL
  // ==========================================================

  /// @dev Adds non-zero tokens to internal genesis token set.
  /// @param allowedGenesisTokens Tokens to add.
  function _setSupportedGenesisTokens(address[] memory allowedGenesisTokens) internal {
    uint256 length = allowedGenesisTokens.length;

    for (uint256 i = 0; i < length; i++) {
      if (allowedGenesisTokens[i] != address(0)) {
        _supportedGenesisTokens.add(allowedGenesisTokens[i]);
      }
    }
  }

  /// @dev Sets support flag for a non-zero vault token and emits change event.
  /// @param allowedVaultToken Token address to mutate.
  /// @param allowed New support flag.
  function _setSupportedVaultToken(address allowedVaultToken, bool allowed) internal {
    if (allowedVaultToken == address(0)) revert CommonErrors.ZeroAddress();
    _supportedVaultAssets[allowedVaultToken] = allowed;
    emit SupportedVaultAssetSet(allowedVaultToken, allowed);
  }

  // ==========================================================
  //                      UPGRADE HOOKS
  // ==========================================================

  /// @dev Restricts UUPS upgrades to default admin role.
  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
