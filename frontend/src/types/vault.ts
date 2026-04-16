export type VaultStatus = "Active" | "Inactive";

export interface Vault {
  address: string;
  asset: string;
  guardian: string;
  registeredAt: string;
  status: VaultStatus;
}

export interface VaultPosition {
  vaultAddress: string;
  asset: string;
  deposited: string;
  shares: string;
  value: string;
}

export interface VaultControls {
  depositsEnabled: boolean;
  withdrawalsEnabled: boolean;
  strategyExecutionEnabled: boolean;
}
