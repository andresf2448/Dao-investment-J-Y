import type { ProtocolCapabilities } from "@/types/capabilities";

export type VaultsStatus = "Active" | "Inactive";
export type VaultsFilterStatus = "All" | VaultsStatus;

export interface VaultItem {
  address: string;
  fullAddress: string;
  asset: string;
  guardian: string;
  status: VaultsStatus;
  registeredAt: string;
}

export interface VaultsFilters {
  asset: string;
  guardian: string;
  status: VaultsFilterStatus;
}

export interface VaultsMetrics {
  totalVaults: number;
  activeVaults: number;
  assetsCovered: number;
  guardianCoverage: number;
}

export interface VaultsModel {
  vaults: VaultItem[];
  filteredVaults: VaultItem[];
  availableAssets: string[];
  availableGuardians: string[];
  isVaultDepositsPaused: boolean;
  isVaultCreationPaused: boolean;
  vaultExplorerStatus: string;
  vaultExplorerSubtitle: string;
  guardianRoutingStatus: string;
  guardianRoutingSubtitle: string;
  registryVisibilityStatus: string;
  registryVisibilitySubtitle: string;
  filters: VaultsFilters;
  metrics: VaultsMetrics;
  capabilities: ProtocolCapabilities;
  setAssetFilter: (asset: string) => void;
  setGuardianFilter: (guardian: string) => void;
  setStatusFilter: (status: VaultsFilterStatus) => void;
}
