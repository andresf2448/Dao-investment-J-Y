import type { ProposalActionInput } from "@/types/models/proposalComposer";

export function createEmptyProposalAction(): ProposalActionInput {
  return {
    id: crypto.randomUUID(),
    target: "",
    value: "0",
    calldata: "",
  };
}

export function isValidProposalCalldata(value: string): boolean {
  const normalized = value.trim();

  if (!normalized.startsWith("0x")) {
    return false;
  }

  return normalized.length % 2 === 0 && /^0x[0-9a-fA-F]*$/.test(normalized);
}

export function isValidProposalExecutionValue(value: string): boolean {
  const normalized = value.trim();

  if (normalized === "") {
    return false;
  }

  return /^\d+$/.test(normalized);
}
