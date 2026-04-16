import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type AdminContractItem = {
  name: string;
  address: string;
  group:
    | "Core Contracts"
    | "Governance Contracts"
    | "Guardian Contracts"
    | "Vault Infrastructure";
};

export type AdminMetrics = {
  contractsTracked: number;
  upgradeableSystems: number;
  diagnostics: "Live" | "Unavailable";
  adminPosture: "Controlled" | "Restricted" | "Unavailable";
};

export type AdminDiagnostic = {
  title: string;
  value: string;
  subtitle: string;
  tone: "success" | "warning" | "neutral";
};

export type AdminModel = {
  metrics: AdminMetrics;
  contracts: AdminContractItem[];
  diagnostics: AdminDiagnostic[];
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useAdminModel(): AdminModel {
  const capabilities = useProtocolCapabilities();

  const contracts: AdminContractItem[] = [
    { name: "ProtocolCore", address: "0xCore...001", group: "Core Contracts" },
    { name: "Treasury", address: "0xTreas...002", group: "Core Contracts" },
    { name: "RiskManager", address: "0xRisk...003", group: "Core Contracts" },
    { name: "StrategyRouter", address: "0xRouter...004", group: "Core Contracts" },

    { name: "GenesisBonding", address: "0xBond...007", group: "Governance Contracts" },
    { name: "DaoGovernor", address: "0xGov...008", group: "Governance Contracts" },
    { name: "TimeLock", address: "0xTime...009", group: "Governance Contracts" },

    { name: "GuardianAdministrator", address: "0xGuard...010", group: "Guardian Contracts" },
    { name: "GuardianBondEscrow", address: "0xEscrow...011", group: "Guardian Contracts" },

    { name: "VaultFactory", address: "0xFactory...005", group: "Vault Infrastructure" },
    { name: "VaultRegistry", address: "0xRegistry...006", group: "Vault Infrastructure" },
  ];

  const metrics: AdminMetrics = {
    contractsTracked: contracts.length,
    upgradeableSystems: 3,
    diagnostics: "Live",
    adminPosture: "Controlled",
  };

  const diagnostics: AdminDiagnostic[] = [
    {
      title: "Vault Creation State",
      value: "Enabled",
      subtitle: "Derived from ProtocolCore pause state",
      tone: "success",
    },
    {
      title: "Vault Deposit State",
      value: "Enabled",
      subtitle: "Derived from ProtocolCore pause state",
      tone: "success",
    },
    {
      title: "Execution Engine",
      value: "Monitoring",
      subtitle: "Derived from RiskManager execution state",
      tone: "warning",
    },
    {
      title: "Bonding Program",
      value: "Active",
      subtitle: "Derived from GenesisBonding finalization state",
      tone: "success",
    },
    {
      title: "Treasury Core Wiring",
      value: "Configured",
      subtitle: "Treasury protocol core reference available",
      tone: "neutral",
    },
    {
      title: "Guardian Escrow Wiring",
      value: "Configured",
      subtitle: "Guardian bond escrow reference available",
      tone: "neutral",
    },
  ];

  // ===== FUTURO =====
  // TODO:
  // contracts -> mover a config central por red (mainnet / sepolia / localhost)
  //
  // metrics.upgradeableSystems:
  // - ProtocolCore
  // - RiskManager
  // - StrategyRouter
  //
  // diagnostics:
  // - ProtocolCore.isVaultCreationPaused()
  // - ProtocolCore.isDepositsPaused()
  // - RiskManager.executionPaused
  // - GenesisBonding.isFinalized
  // - Treasury.protocolCore
  // - GuardianAdministrator.bondEscrow
  //
  // adminPosture:
  // - derivar desde capabilities reales de la wallet conectada
  //
  // capabilities:
  // - usar canAccessAdminConsole
  // - exponer capacidades operativas si quieres enriquecer la consola

  return {
    metrics,
    contracts,
    diagnostics,
    capabilities,
  };
}