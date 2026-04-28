import type { ProtocolCapabilities } from "@/types/capabilities";

export type VaultDetailStatus = "Active" | "Inactive";

export interface VaultDetailData {
  address: string;
  asset: string;
  guardian: string;
  status: VaultDetailStatus;
  registeredAt: string;
  decimals: number;
  totalAssets: string;
}

export interface VaultDetailPosition {
  depositedAssets: string;
  mintedShares: string;
  withdrawableAssets: string;
  redeemableShares: string;
}

export interface VaultDetailControls {
  depositsEnabled: boolean;
  strategyExecutionEnabled: boolean;
}

export interface VaultDetailModel {
  vault: VaultDetailData;
  position: VaultDetailPosition;
  controls: VaultDetailControls;
  capabilities: ProtocolCapabilities;
  isSubmitting: boolean;
  depositAssetBalance: string;
  hasDepositAssetBalance: boolean;
  isVaultGuardian: boolean;
  canShowGuardianOperations: boolean;
  deposit: (amount: string) => Promise<boolean>;
  mint: (amount: string) => Promise<boolean>;
  withdraw: (amount: string) => Promise<boolean>;
  redeem: (amount: string) => Promise<boolean>;
  executeStrategy: () => Promise<boolean>;
}
