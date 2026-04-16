import { useState } from "react";
import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type GuardianVaultAsset = {
  symbol: string;
  address: string;
};

export type GuardianVaultToolsModel = {
  assets: GuardianVaultAsset[];
  selectedAsset: GuardianVaultAsset | null;
  setSelectedAsset: (asset: GuardianVaultAsset) => void;

  vaultName: string;
  setVaultName: (value: string) => void;

  vaultSymbol: string;
  setVaultSymbol: (value: string) => void;

  predictedAddress: string;
  pairExists: boolean;

  canCreateVault: boolean;
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useGuardianVaultToolsModel(): GuardianVaultToolsModel {
  const capabilities = useProtocolCapabilities();

  const assets: GuardianVaultAsset[] = [
    { symbol: "USDC", address: "0xUSDC" },
    { symbol: "DAI", address: "0xDAI" },
    { symbol: "ETH", address: "0xETH" },
  ];

  const [selectedAsset, setSelectedAsset] = useState<GuardianVaultAsset | null>(
    assets[0]
  );
  const [vaultName, setVaultName] = useState("JY USDC Vault");
  const [vaultSymbol, setVaultSymbol] = useState("jyUSDC");

  const predictedAddress = "0xPredicted...Vault";
  const pairExists = false;

  const canCreateVault =
    capabilities.canCreateVault &&
    !!selectedAsset &&
    vaultName.trim() !== "" &&
    vaultSymbol.trim() !== "" &&
    !pairExists;

  // TODO:
  // assets -> activos soportados desde ProtocolCore / configuración por red
  // predictedAddress -> VaultFactory.predictVaultAddress(...)
  // pairExists -> VaultFactory.isDeployed(...) o chequeo equivalente
  // canCreateVault -> también debe considerar:
  // - guardian activo
  // - vault creation no pausada
  // - asset soportado
  // - no vault previo para guardian + asset
  //
  // write:
  // VaultFactory.createVault(asset, name, symbol)

  return {
    assets,
    selectedAsset,
    setSelectedAsset,
    vaultName,
    setVaultName,
    vaultSymbol,
    setVaultSymbol,
    predictedAddress,
    pairExists,
    canCreateVault,
    capabilities,
  };
}