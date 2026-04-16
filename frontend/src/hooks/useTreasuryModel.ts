import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type TreasuryAssetCategory = "DAO Asset" | "Non-DAO Asset";
export type TreasuryAssetType = "Native" | "ERC20";

export type TreasuryAsset = {
  token: string;
  type: TreasuryAssetType;
  balance: string;
  category: TreasuryAssetCategory;
  visibility: "Tracked" | "Unavailable";
};

export type TreasuryMetrics = {
  nativeBalance: string;
  trackedErc20Assets: number;
  daoAssetExposure: string;
  operationalLiquidity: string;
};

export type TreasuryModel = {
  assets: TreasuryAsset[];
  metrics: TreasuryMetrics;
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useTreasuryModel(): TreasuryModel {
  const capabilities = useProtocolCapabilities();

  // ===== MOCK ASSETS =====
  const assets: TreasuryAsset[] = [
    {
      token: "ETH",
      type: "Native",
      balance: "320.45",
      category: "DAO Asset",
      visibility: "Tracked",
    },
    {
      token: "USDC",
      type: "ERC20",
      balance: "4,250,000",
      category: "DAO Asset",
      visibility: "Tracked",
    },
    {
      token: "DAI",
      type: "ERC20",
      balance: "3,180,000",
      category: "DAO Asset",
      visibility: "Tracked",
    },
    {
      token: "LINK",
      type: "ERC20",
      balance: "18,500",
      category: "Non-DAO Asset",
      visibility: "Tracked",
    },
  ];

  const metrics: TreasuryMetrics = {
    nativeBalance: "320 ETH",
    trackedErc20Assets: assets.filter((asset) => asset.type === "ERC20").length,
    daoAssetExposure: "$12.4M",
    operationalLiquidity: "Stable",
  };

  // ===== FUTURO =====
  // TODO:
  // metrics.nativeBalance -> Treasury.nativeBalance()
  // balances ERC20 -> Treasury.erc20Balance(token)
  // clasificación DAO / Non-DAO -> ProtocolCore.hasGenesisToken(token)
  // daoAssetExposure -> agregación por pricing layer / subgraph / backend auxiliar
  //
  // assets:
  // - token list configurable por red
  // - Native = ETH/MATIC/etc según chain
  // - ERC20 balances obtenidos y formateados por token
  //
  // capabilities.canOpenTreasuryOperations ->
  // derivado desde useProtocolCapabilities()

  return {
    assets,
    metrics,
    capabilities,
  };
}