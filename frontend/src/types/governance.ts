export type ProposalStatus = "Pending" | "Active" | "Queued" | "Executed" | "Defeated" | "Canceled";

export interface ProposalVotes {
  forVotes: string;
  againstVotes: string;
  abstainVotes: string;
}

export interface ProposalAction {
  target: string;
  value: string;
  calldata: string;
}

export interface ProposalTimeline {
  label: string;
  value: string;
}

export interface Proposal {
  id: string;
  title: string;
  description: string;
  status: ProposalStatus;
  proposer: string;
  votes: ProposalVotes;
  actions: ProposalAction[];
  timeline: ProposalTimeline[];
  endDate: string;
  executionEta: string;
}
