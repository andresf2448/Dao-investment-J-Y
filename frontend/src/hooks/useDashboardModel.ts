import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type DashboardMetrics = {
  totalVaults: number;
  treasuryValue: string;
  proposalThreshold: string;
  guardianCount: number;
};

export type ProtocolStatus = {
  network: string;
  bonding: "active" | "finalized";
  vaultCreation: "enabled" | "paused";
  deposits: "enabled" | "paused";
  execution: "monitoring" | "paused";
};

export type ActivityItem = {
  id: string;
  title: string;
  description: string;
};

export type DashboardModel = {
  metrics: DashboardMetrics;
  status: ProtocolStatus;
  activity: ActivityItem[];
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useDashboardModel(): DashboardModel {
  const capabilities = useProtocolCapabilities();

  // ===== MOCK DATA =====
  // TODO: reemplazar TODO esto por datos reales desde contratos / indexador

  const metrics: DashboardMetrics = {
    totalVaults: 62,
    treasuryValue: "$17.7M",
    proposalThreshold: "4%",
    guardianCount: 14,
  };

  const status: ProtocolStatus = {
    network: "Ethereum Mainnet",
    bonding: "active",
    vaultCreation: "enabled",
    deposits: "enabled",
    execution: "monitoring",
  };

  const activity: ActivityItem[] = [
    {
      id: "1",
      title: "Guardian application submitted",
      description: "A new guardian entered governance review.",
    },
    {
      id: "2",
      title: "Vault deployed",
      description: "A new vault was registered in the protocol.",
    },
    {
      id: "3",
      title: "Treasury updated",
      description: "Balances refreshed across tracked assets.",
    },
  ];

  // ===== FUTURO =====
  // TODO:
  // metrics.totalVaults -> VaultRegistry.totalVaults()
  // treasuryValue -> Treasury.nativeBalance + erc20Balance aggregation
  // proposalThreshold -> DaoGovernor.proposalThreshold()
  // guardianCount -> GuardianAdministrator (si indexas)
  //
  // status.bonding -> GenesisBonding.isFinalized()
  // status.vaultCreation -> ProtocolCore.isVaultCreationPaused()
  // status.deposits -> ProtocolCore.isDepositsPaused()
  // status.execution -> RiskManager.executionPaused
  //
  // activity -> eventos (subgraph idealmente)

  return {
    metrics,
    status,
    activity,
    capabilities,
  };
}