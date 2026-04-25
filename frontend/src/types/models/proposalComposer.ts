import type { ProtocolCapabilities } from "@/types/capabilities";

export interface ProposalActionInput {
  id: string;
  target: string;
  value: string;
  calldata: string;
}

export interface ProposalComposerModel {
  title: string;
  setTitle: (value: string) => void;
  description: string;
  setDescription: (value: string) => void;
  actions: ProposalActionInput[];
  addAction: () => void;
  updateAction: (
    id: string,
    field: keyof Omit<ProposalActionInput, "id">,
    value: string,
  ) => void;
  removeAction: (id: string) => void;
  votingPower: string;
  proposalThreshold: string;
  meetsThreshold: boolean;
  delegateAddress: string;
  setDelegateAddress: (value: string) => void;
  delegateAddressError?: string;
  canDelegateVotes: boolean;
  isDelegatingVotes: boolean;
  delegateVotes: () => Promise<void>;
  submitProposal: () => Promise<void>;
  canSubmitProposal: boolean;
  isSubmitting: boolean;
  capabilities: ProtocolCapabilities;
}
