export type AssetCategory = "DAO Asset" | "Non-DAO Asset";
export type AssetVisibility = "Public" | "Private" | "Restricted";
export type AssetType = "Native" | "ERC20";

export interface TreasuryAsset {
  token: string;
  type: AssetType;
  balance: string;
  category: AssetCategory;
  visibility: AssetVisibility;
}

export interface TreasuryMetrics {
  nativeBalance: string;
  trackedErc20Assets: number;
  daoAssetExposure: string;
  operationalLiquidity: string;
}
