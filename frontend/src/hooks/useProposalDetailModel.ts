import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type ProposalDetailStatus =
  | "Pending"
  | "Active"
  | "Succeeded"
  | "Defeated"
  | "Queued"
  | "Executed"
  | "Canceled";

export type ProposalVoteBreakdown = {
  forVotes: string;
  againstVotes: string;
  abstainVotes: string;
};

export type ProposalTimelineItem = {
  label: string;
  value: string;
};

export type ProposalDetailData = {
  id: string;
  title: string;
  status: ProposalDetailStatus;
  description: string;
  proposer: string;
  executionEta: string;
  votes: ProposalVoteBreakdown;
  timeline: ProposalTimelineItem[];
  actions: Array<{
    target: string;
    value: string;
    calldata: string;
  }>;
};

export type ProposalDetailModel = {
  proposal: ProposalDetailData;
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useProposalDetailModel(
  proposalId?: string
): ProposalDetailModel {
  const capabilities = useProtocolCapabilities();

  const proposal: ProposalDetailData = {
    id: proposalId ?? "P-101",
    title: "Update supported vault asset policy",
    status: "Queued",
    description:
      "This proposal updates the supported vault asset policy to align deployment controls with the latest protocol risk framework and treasury coordination requirements.",
    proposer: "0xF12A...91ce",
    executionEta: "2026-02-12 14:00 UTC",
    votes: {
      forVotes: "412,950 GOV",
      againstVotes: "54,210 GOV",
      abstainVotes: "8,120 GOV",
    },
    timeline: [
      { label: "Created", value: "2026-02-05 10:00 UTC" },
      { label: "Voting Delay", value: "24h" },
      { label: "Voting Open", value: "2026-02-06 10:00 UTC" },
      { label: "Voting End", value: "2026-02-09 10:00 UTC" },
      { label: "Queued", value: "2026-02-10 14:00 UTC" },
      { label: "Executable ETA", value: "2026-02-12 14:00 UTC" },
    ],
    actions: [
      {
        target: "0xCore...001",
        value: "0",
        calldata: "0xabcdef123456",
      },
      {
        target: "0xFactory...005",
        value: "0",
        calldata: "0x987654fedcba",
      },
    ],
  };

  // TODO:
  // proposal.id -> route param /governance/:proposalId
  // proposal.status -> DaoGovernor.state(proposalId)
  // proposal.description -> fuente indexada / metadata / evento
  // proposal.proposer -> datos del governor o fuente indexada
  // proposal.executionEta -> Timelock / queue timestamp
  // proposal.votes -> DaoGovernor.proposalVotes(proposalId)
  // proposal.timeline -> construir desde snapshot, deadline, queue eta y execution state
  // proposal.actions -> targets / values / calldatas reales de la propuesta
  //
  // futura interacción:
  // - castVote / castVoteWithReason
  // - queue
  // - execute

  return {
    proposal,
    capabilities,
  };
}