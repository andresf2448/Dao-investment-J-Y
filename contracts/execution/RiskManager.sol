// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// =============================================================
//                           IMPORTS
// =============================================================
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IRiskManager} from "../interfaces/execution/IRiskManager.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";

// =============================================================
//                          CONTRACTS
// =============================================================

/// @title RiskManager
/// @notice Validates whether strategy execution can proceed for a given asset.
/// @dev Uses Chainlink feeds with heartbeat checks and optional depeg bounds for stable assets.
contract RiskManager is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IRiskManager {

  /*//////////////////////////////////////////////////////////////
                              TYPE DECLARATIONS
  //////////////////////////////////////////////////////////////*/
  
  /// @notice Price validation configuration per asset.
  struct AssetConfig {
    /// @notice Chainlink feed used to validate asset price.
    address feed;
    /// @notice Maximum staleness tolerated for the feed update.
    uint48 heartbeat;
    /// @notice Indicates if depeg checks should be enforced around $1.
    bool isStable;
    /// @notice Lower depeg bound in bps relative to 1e18 for stable assets.
    uint16 depegMinBps;
    /// @notice Upper depeg bound in bps relative to 1e18 for stable assets.
    uint16 depegMaxBps;
    /// @notice Whether the asset can be used for execution validation.
    bool enabled;
  }

  /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  /// @notice Role allowed to configure assets and upgrade policy values.
  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

  /// @notice Role allowed to pause or unpause all adapter execution.
  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

  /// @dev Basis points denominator (100% = 10_000 bps).
  uint256 internal constant BPS_DENOMINATOR = 10_000;

  /// @dev Price target for stable assets normalized to 18 decimals.
  uint256 internal constant TARGET_STABLE_PRICE = 1e18;

  /// @dev Asset configuration storage keyed by asset address.
  mapping(address asset => AssetConfig config) private _assetConfigs;

  /// @notice Global flag that pauses all execution validation.
  bool public executionPaused;

  /*//////////////////////////////////////////////////////////////
                                  EVENTS
  //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when an asset risk configuration is updated.
  event AssetConfigSet(
    address indexed asset,
    address indexed feed,
    uint48 heartbeat,
    bool isStable,
    uint16 depegMinBps,
    uint16 depegMaxBps,
    bool enabled
  );

  /// @notice Emitted when execution pause status changes.
  event ExecutionPausedSet(bool paused);

  /*//////////////////////////////////////////////////////////////
                                  ERRORS
  //////////////////////////////////////////////////////////////*/
  /// @notice Thrown when heartbeat is zero.
  error RiskManager__InvalidHeartbeat();

  /// @notice Thrown when depeg bounds are malformed for chosen asset mode.
  error RiskManager__InvalidBpsRange();

  /// @notice Thrown when execution is globally paused.
  error RiskManager__ExecutionPaused();

  /// @notice Thrown when requested asset is not enabled.
  error RiskManager__AssetNotEnabled();

  /// @notice Thrown when oracle price is non-positive or normalizes to zero.
  error RiskManager__InvalidPrice();

  /// @notice Thrown when oracle update is older than configured heartbeat.
  error RiskManager__StalePrice();

  /// @notice Thrown when round metadata is invalid.
  error RiskManager__InvalidRound();

  /// @notice Thrown when stable asset price goes outside configured depeg bounds.
  error RiskManager__DepegDetected();

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

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @notice Initializes roles for administration and emergency response.
  /// @param adminTimelock Address receiving default admin and manager roles.
  /// @param emergencyOperator Address receiving emergency pause role.
  function initialize(address adminTimelock, address emergencyOperator) external initializer {
    if (adminTimelock == address(0) || emergencyOperator == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    __AccessControl_init();

    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock);
    _grantRole(MANAGER_ROLE, adminTimelock);
    _grantRole(EMERGENCY_ROLE, emergencyOperator);
  }

  /// @notice Configures price feed and risk bounds for an asset.
  /// @param asset Asset address to configure.
  /// @param feed Chainlink feed contract used for pricing.
  /// @param heartbeat Maximum allowed delay between updates.
  /// @param isStable Whether stable depeg validation should be enforced.
  /// @param depegMinBps Minimum allowed stable price in bps (e.g. 9_800 = 0.98).
  /// @param depegMaxBps Maximum allowed stable price in bps (e.g. 10_200 = 1.02).
  /// @param enabled Whether the asset is enabled for execution.
  function setAssetConfig(
    address asset,
    address feed,
    uint48 heartbeat,
    bool isStable,
    uint16 depegMinBps,
    uint16 depegMaxBps,
    bool enabled
  ) external onlyRole(MANAGER_ROLE) {
    if (asset == address(0) || feed == address(0)) {
      revert CommonErrors.ZeroAddress();
    }

    if (heartbeat == 0) revert RiskManager__InvalidHeartbeat();

    if (isStable) {
      if (depegMinBps == 0 || depegMaxBps == 0) {
        revert RiskManager__InvalidBpsRange();
      }
      if (depegMinBps > BPS_DENOMINATOR || depegMaxBps < BPS_DENOMINATOR) {
        revert RiskManager__InvalidBpsRange();
      }
      if (depegMinBps > depegMaxBps) {
        revert RiskManager__InvalidBpsRange();
      }
    } else {
      if (depegMinBps != 0 || depegMaxBps != 0) {
        revert RiskManager__InvalidBpsRange();
      }
    }

    _assetConfigs[asset] = AssetConfig({
      feed: feed,
      heartbeat: heartbeat,
      isStable: isStable,
      depegMinBps: depegMinBps,
      depegMaxBps: depegMaxBps,
      enabled: enabled
    });

    emit AssetConfigSet(asset, feed, heartbeat, isStable, depegMinBps, depegMaxBps, enabled);
  }

  /// @notice Pauses all strategy execution validations.
  function pauseAdapterExecution() external onlyRole(EMERGENCY_ROLE) {
    executionPaused = true;
    emit ExecutionPausedSet(true);
  }

  /// @notice Unpauses strategy execution validations.
  function unpauseAdapterExecution() external onlyRole(EMERGENCY_ROLE) {
    executionPaused = false;
    emit ExecutionPausedSet(false);
  }

  /// @notice Returns stored configuration for an asset.
  /// @param asset Asset to query.
  /// @return Current config for the asset.
  function getAssetConfig(address asset) external view returns (AssetConfig memory) {
    return _assetConfigs[asset];
  }

  /// @notice Returns asset config fields as tuple for easier tests.
  /// @param asset Asset to query.
  /// @return feed Chainlink feed address.
  /// @return heartbeat Max delay allowed for a fresh price.
  /// @return isStable True if depeg checks are enabled.
  /// @return depegMinBps Stable lower bound in bps.
  /// @return depegMaxBps Stable upper bound in bps.
  /// @return enabled True if asset is enabled.
  function getAssetConfigFields(address asset)
    external
    view
    returns (
      address feed,
      uint48 heartbeat,
      bool isStable,
      uint16 depegMinBps,
      uint16 depegMaxBps,
      bool enabled
    )
  {
    AssetConfig memory config = _assetConfigs[asset];
    return (
      config.feed,
      config.heartbeat,
      config.isStable,
      config.depegMinBps,
      config.depegMaxBps,
      config.enabled
    );
  }

  // ==========================================================
  //                          EXTERNAL
  // ==========================================================

  /// @inheritdoc IRiskManager
  function validateExecution(address asset) external view override {
    if (executionPaused) revert RiskManager__ExecutionPaused();

    AssetConfig memory config = _assetConfigs[asset];
    if (!config.enabled) revert RiskManager__AssetNotEnabled();
    if (config.feed == address(0)) revert CommonErrors.ZeroAddress();

    uint256 normalizedPrice = _validatedPrice(config);

    if (config.isStable) {
      uint256 minPrice = (TARGET_STABLE_PRICE * config.depegMinBps) / BPS_DENOMINATOR;
      uint256 maxPrice = (TARGET_STABLE_PRICE * config.depegMaxBps) / BPS_DENOMINATOR;

      if (normalizedPrice < minPrice || normalizedPrice > maxPrice) {
        revert RiskManager__DepegDetected();
      }
    }
  }

  /// @inheritdoc IRiskManager
  function getValidatedPrice(address asset) external view override returns (uint256) {
    AssetConfig memory config = _assetConfigs[asset];
    if (!config.enabled) revert RiskManager__AssetNotEnabled();
    if (config.feed == address(0)) revert CommonErrors.ZeroAddress();

    return _validatedPrice(config);
  }

  /// @inheritdoc IRiskManager
  function isAssetHealthy(address asset) external view override returns (bool) {
    if (executionPaused) return false;

    AssetConfig memory config = _assetConfigs[asset];
    if (!config.enabled || config.feed == address(0)) return false;

    try this.getValidatedPrice(asset) returns (uint256 price) {
      if (!config.isStable) return price > 0;

      uint256 minPrice = (TARGET_STABLE_PRICE * config.depegMinBps) / BPS_DENOMINATOR;
      uint256 maxPrice = (TARGET_STABLE_PRICE * config.depegMaxBps) / BPS_DENOMINATOR;

      return price >= minPrice && price <= maxPrice;
    } catch {
      return false;
    }
  }

  // ==========================================================
  //                          INTERNAL
  // ==========================================================

  /// @dev Reads and normalizes a Chainlink price to 18 decimals while enforcing staleness checks.
  /// @param config Asset config holding feed and heartbeat settings.
  /// @return normalizedPrice Latest positive normalized price.
  function _validatedPrice(AssetConfig memory config) internal view returns (uint256 normalizedPrice) {
    (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
      AggregatorV3Interface(config.feed).latestRoundData();

    if (roundId == 0 || answeredInRound < roundId) revert RiskManager__InvalidRound();

    if (answer <= 0) revert RiskManager__InvalidPrice();
    if (updatedAt == 0) revert RiskManager__InvalidRound();
    if (block.timestamp > updatedAt + uint256(config.heartbeat)) {
      revert RiskManager__StalePrice();
    }

    uint8 decimals = AggregatorV3Interface(config.feed).decimals();
    // casting to uint256 is safe because answer > 0 was already checked above
    // forge-lint: disable-next-line(unsafe-typecast)
    uint256 unsignedAnswer = uint256(answer);

    if (decimals == 18) {
      normalizedPrice = unsignedAnswer;
    } else if (decimals < 18) {
      normalizedPrice = unsignedAnswer * (10 ** (18 - decimals));
    } else {
      normalizedPrice = unsignedAnswer / (10 ** (decimals - 18));
    }

    if (normalizedPrice == 0) revert RiskManager__InvalidPrice();
  }

  /// @dev Restricts UUPS upgrades to default admin role.
  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
