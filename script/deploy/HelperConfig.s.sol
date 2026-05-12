// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
  struct NetworkConfig {
    address[] allowedGenesisTokens;
    uint256 deployerPrivateKey;
    address aavePool;
    address compoundComet;
    string networkName;
    address allowedVaultToken;
    address mockV3Aggregator;
  }

  NetworkConfig private activeNetworkConfig;

  constructor() {
    if (block.chainid == 31337) {
      activeNetworkConfig = getOrCreateAnvilConfig();
    } else if (block.chainid == 11155111) {
      activeNetworkConfig = getSepoliaConfig();
    } else {
      activeNetworkConfig = getEnvNetworkConfig();
    }
  }

  function getSepoliaConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
    address[] memory allowedGenesisTokens = new address[](1);
    allowedGenesisTokens[0] = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    sepoliaNetworkConfig = NetworkConfig({
      allowedGenesisTokens: allowedGenesisTokens,
      allowedVaultToken: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
      deployerPrivateKey: vm.envUint("SEPOLIA_PRIVATE_KEY"),
      aavePool: 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2,
      compoundComet: 0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e,
      mockV3Aggregator: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
      networkName: "sepolia"
    });
  }

  function getOrCreateAnvilConfig() public view returns (NetworkConfig memory anvilNetworkConfig) {
    if (activeNetworkConfig.allowedGenesisTokens.length > 0) return activeNetworkConfig;

    // Los mocks se desplegarán en cada script individual dentro de vm.startBroadcast
    address[] memory allowedGenesisTokens = new address[](1);
    allowedGenesisTokens[0] = address(0); // Placeholder, se reemplazará en cada deploy

    anvilNetworkConfig = NetworkConfig({
      allowedGenesisTokens: allowedGenesisTokens,
      allowedVaultToken: address(0), // Placeholder, se reemplazará en cada deploy
      deployerPrivateKey: vm.envUint("DEFAULT_ANVIL_PRIVATE_KEY"),
      aavePool: address(0), // Placeholder, se reemplazará en cada deploy
      compoundComet: address(0), // Placeholder, se reemplazará en cada deploy
      mockV3Aggregator: address(0), // Placeholder, se reemplazará en cada deploy
      networkName: "anvil"
    });

    return anvilNetworkConfig;
  }

  function getEnvNetworkConfig() public view returns (NetworkConfig memory envNetworkConfig) {
    address[] memory allowedGenesisTokens = new address[](1);
    allowedGenesisTokens[0] = vm.envAddress("ALLOWED_GENESIS_TOKEN");

    envNetworkConfig = NetworkConfig({
      allowedGenesisTokens: allowedGenesisTokens,
      allowedVaultToken: vm.envAddress("ALLOWED_VAULT_TOKEN"),
      deployerPrivateKey: vm.envUint("PRIVATE_KEY"),
      aavePool: vm.envAddress("AAVE_POOL"),
      compoundComet: vm.envAddress("COMPOUND_COMET"),
      mockV3Aggregator: vm.envAddress("PRICE_FEED"),
      networkName: vm.envString("NETWORK_NAME")
    });
  }

  function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
    return activeNetworkConfig;
  }
}
