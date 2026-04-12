// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IRiskManager} from "../interfaces/execution/IRiskManager.sol";
import {CommonErrors} from "../libraries/errors/CommonErrors.sol";

contract RiskManager is
  Initializable,
  AccessControlUpgradeable,
  UUPSUpgradeable,
  IRiskManager
{
  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
  uint256 internal constant BPS_DENOMINATOR = 10_000;
  uint256 internal constant TARGET_STABLE_PRICE = 1e18;

  struct AssetConfig {
    address feed;
    uint48 heartbeat;
    bool isStable;
    uint16 depegMinBps;
    uint16 depegMaxBps;
    bool enabled;
  }

  mapping(address asset => AssetConfig config) private _assetConfigs;

  bool public executionPaused;

  event AssetConfigSet(
    address indexed asset,
    address indexed feed,
    uint48 heartbeat,
    bool isStable,
    uint16 depegMinBps,
    uint16 depegMaxBps,
    bool enabled
  );
  event ExecutionPausedSet(bool paused);

  error RiskManager__InvalidHeartbeat();
  error RiskManager__InvalidBpsRange();
  error RiskManager__ExecutionPaused();
  error RiskManager__AssetNotEnabled();
  error RiskManager__InvalidPrice();
  error RiskManager__StalePrice();
  error RiskManager__InvalidRound();
  error RiskManager__DepegDetected();

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address adminTimelock,
    address emergencyOperator
  ) external initializer {
    if(adminTimelock == address(0) || emergencyOperator == address(0))
      revert CommonErrors.ZeroAddress();

    __AccessControl_init();

    _grantRole(DEFAULT_ADMIN_ROLE, adminTimelock);
    _grantRole(MANAGER_ROLE, adminTimelock);
    _grantRole(EMERGENCY_ROLE, emergencyOperator);
  }

  function setAssetConfig(
    address asset,
    address feed,
    uint48 heartbeat,
    bool isStable,
    uint16 depegMinBps,
    uint16 depegMaxBps,
    bool enabled
  ) external onlyRole(MANAGER_ROLE) {
    if(asset == address(0) || feed == address(0))
      revert CommonErrors.ZeroAddress();

    if (heartbeat == 0) revert RiskManager__InvalidHeartbeat();

    if (isStable) {
      if (depegMinBps == 0 || depegMaxBps == 0)
        revert RiskManager__InvalidBpsRange();
      if (depegMinBps > BPS_DENOMINATOR || depegMaxBps > BPS_DENOMINATOR)
        revert RiskManager__InvalidBpsRange();
      if (depegMinBps > depegMaxBps)
        revert RiskManager__InvalidBpsRange();
    } else {
      if (depegMinBps != 0 || depegMaxBps != 0)
        revert RiskManager__InvalidBpsRange();
    }

    _assetConfigs[asset] = AssetConfig({
      feed: feed,
      heartbeat: heartbeat,
      isStable: isStable,
      depegMinBps: depegMinBps,
      depegMaxBps: depegMaxBps,
      enabled: enabled
    });

    emit AssetConfigSet(
      asset,
      feed,
      heartbeat,
      isStable,
      depegMinBps,
      depegMaxBps,
      enabled
    );
  }

  function pauseAdapterExecution() external onlyRole(EMERGENCY_ROLE) {
    executionPaused = true;
    emit ExecutionPausedSet(true);
  }

  function unpauseAdapterExecution() external onlyRole(MANAGER_ROLE) {
    executionPaused = false;
    emit ExecutionPausedSet(false);
  }

  function getAssetConfig(address asset)
    external
    view
    returns(AssetConfig memory)
  {
    return _assetConfigs[asset];
  }

  function validateExecution(
    address,
    address asset,
    address,
    bytes calldata
  ) external view override {
    if(executionPaused) revert RiskManager__ExecutionPaused();

    AssetConfig memory config = _assetConfigs[asset];
    if(!config.enabled) revert RiskManager__AssetNotEnabled();
    if(config.feed == address(0)) revert CommonErrors.ZeroAddress();

    uint256 normalizedPrice = _validatedPrice(config);

    if(config.isStable) {
      uint256 minPrice = (TARGET_STABLE_PRICE * config.depegMinBps) / BPS_DENOMINATOR;
      uint256 maxPrice = (TARGET_STABLE_PRICE * config.depegMaxBps) / BPS_DENOMINATOR;

      if(normalizedPrice < minPrice || normalizedPrice > maxPrice)
        revert RiskManager__DepegDetected();
    }
  }

  function getValidatedPrice(address asset)
    external
    view
    override
    returns(uint256)
  {
    AssetConfig memory config = _assetConfigs[asset];
    if(!config.enabled) revert RiskManager__AssetNotEnabled();
    if(config.feed == address(0)) revert CommonErrors.ZeroAddress();

    return _validatedPrice(config);
  }

  function isAssetHealthy(address asset)
    external
    view
    override
    returns (bool)
  {
    if(executionPaused) return false;

    AssetConfig memory config = _assetConfigs[asset];
    if(!config.enabled || config.feed == address(0)) return false;

    try this.getValidatedPrice(asset) returns(uint256 price) {
      if(!config.isStable) return price > 0;

      uint256 minPrice = (TARGET_STABLE_PRICE * config.depegMinBps) / BPS_DENOMINATOR;
      uint256 maxPrice = (TARGET_STABLE_PRICE * config.depegMaxBps) / BPS_DENOMINATOR;

      return price >= minPrice && price <= maxPrice;
    } catch {
      return false;
    }
  }

  function _validatedPrice(AssetConfig memory config)
    internal
    view
    returns(uint256 normalizedPrice)
  {
    (
      uint80 roundId,
      int256 answer,
      ,
      uint256 updatedAt,
      uint80 answeredInRound
    ) = AggregatorV3Interface(config.feed).latestRoundData();

    if(roundId == 0 || answeredInRound < roundId) revert RiskManager__InvalidRound();

    if(answer <= 0) revert RiskManager__InvalidPrice();
    if(updatedAt == 0) revert RiskManager__InvalidRound();
    if(block.timestamp > updatedAt + uint256(config.heartbeat))
      revert RiskManager__StalePrice();

    uint8 decimals = AggregatorV3Interface(config.feed).decimals();
    // casting to 'uint256' is safe because Chainlink price feeds will never return a negative price, and we already checked that 'answer' is greater than 0
    // forge-lint: disable-next-line(unsafe-typecast)
    uint256 unsignedAnswer = uint256(answer);

    if(decimals == 18) {
      normalizedPrice = unsignedAnswer;
    } else if (decimals < 18) {
      normalizedPrice = unsignedAnswer * (10 ** (18 - decimals));
    } else {
      normalizedPrice = unsignedAnswer / (10 ** (decimals - 18));
    }

    if(normalizedPrice == 0) revert RiskManager__InvalidPrice();
  }

  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
