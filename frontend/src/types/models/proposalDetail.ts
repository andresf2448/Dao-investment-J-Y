import type { ProtocolCapabilities } from "@/types/capabilities";

export type ProposalDetailStatus =
  | "Pending"
  | "Active"
  | "Succeeded"
  | "Defeated"
  | "Queued"
  | "Executed"
  | "Canceled"
  | "Expired";

export interface ProposalVoteBreakdown {
  forVotes: string;
  againstVotes: string;
  abstainVotes: string;
}

export interface ProposalTimelineItem {
  label: string;
  value: string;
}

export interface ProposalDetailAction {
  target: string;
  value: string;
  calldata: string;
}

export interface ProposalDetailData {
  id: string;
  title: string;
  status: ProposalDetailStatus;
  description: string;
  proposer: string;
  executionEta: string;
  delegatedVotes: string;
  votes: ProposalVoteBreakdown;
  timeline: ProposalTimelineItem[];
  actions: ProposalDetailAction[];
}

export interface ProposalDetailModel {
  proposal: ProposalDetailData;
  capabilities: ProtocolCapabilities;
  canVote: boolean;
  canExecuteProposal: boolean;
  voteFor: () => Promise<void>;
  voteAgainst: () => Promise<void>;
  abstain: () => Promise<void>;
  executeProposal: () => Promise<void>;
  isSubmitting: boolean;
}
