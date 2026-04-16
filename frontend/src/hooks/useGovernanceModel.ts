import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type GovernanceStatus =
  | "Pending"
  | "Active"
  | "Succeeded"
  | "Defeated"
  | "Queued"
  | "Executed"
  | "Canceled";

export type GovernanceProposal = {
  id: string;
  title: string;
  status: GovernanceStatus;
  votes: string;
  endDate: string;
};

export type GovernanceConfig = {
  proposalThreshold: string;
  votingDelay: string;
  votingPeriod: string;
  executionDelay: string;
};

export type GovernanceMetrics = {
  activeProposals: number;
  queuedProposals: number;
  executedProposals: number;
  participation: string;
};

export type GovernanceUserState = {
  votingPower: string;
  meetsProposalThreshold: boolean;
};

export type GovernanceModel = {
  config: GovernanceConfig;
  metrics: GovernanceMetrics;
  proposals: GovernanceProposal[];
  user: GovernanceUserState;
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useGovernanceModel(): GovernanceModel {
  const capabilities = useProtocolCapabilities();

  // ===== MOCK CONFIG =====
  const config: GovernanceConfig = {
    proposalThreshold: "4%",
    votingDelay: "24h",
    votingPeriod: "72h",
    executionDelay: "48h",
  };

  // ===== MOCK PROPOSALS =====
  const proposals: GovernanceProposal[] = [
    {
      id: "P-101",
      title: "Update supported vault asset policy",
      status: "Active",
      votes: "412,950 GOV",
      endDate: "2026-02-10",
    },
    {
      id: "P-102",
      title: "Allocate treasury reserves to protocol operations",
      status: "Queued",
      votes: "389,100 GOV",
      endDate: "2026-02-08",
    },
    {
      id: "P-103",
      title: "Adjust guardian minimum stake",
      status: "Executed",
      votes: "501,330 GOV",
      endDate: "2026-02-02",
    },
  ];

  // ===== METRICS =====
  const metrics: GovernanceMetrics = {
    activeProposals: proposals.filter((p) => p.status === "Active").length,
    queuedProposals: proposals.filter((p) => p.status === "Queued").length,
    executedProposals: proposals.filter((p) => p.status === "Executed").length,
    participation: "62%",
  };

  // ===== MOCK USER STATE =====
  const user: GovernanceUserState = {
    votingPower: "0 GOV",
    meetsProposalThreshold: false,
  };

  // ===== FUTURO =====
  // TODO:
  // config.proposalThreshold -> DaoGovernor.proposalThreshold()
  // config.votingDelay -> DaoGovernor.votingDelay()
  // config.votingPeriod -> DaoGovernor.votingPeriod()
  // config.executionDelay -> TimeLock minDelay
  //
  // proposals -> fuente RPC / Graph / indexación de eventos
  // proposals.status -> DaoGovernor.state(proposalId)
  //
  // user.votingPower -> GovernanceToken / IVotes.getVotes(user, blockNumber)
  // user.meetsProposalThreshold -> comparar votingPower vs proposalThreshold
  //
  // capabilities.canCreateProposal debería derivarse usando este estado real

  return {
    config,
    metrics,
    proposals,
    user,
    capabilities,
  };
}