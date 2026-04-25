export interface ProposalMetadata {
  proposalId: string;
  title: string;
  description: string;
  composedDescription: string;
}

const PROPOSAL_METADATA_KEY_PREFIX = "jy:governance:proposal-metadata:v1";

function getProposalMetadataStorageKey(
  chainId: number | undefined,
  proposalId: string,
): string {
  return `${PROPOSAL_METADATA_KEY_PREFIX}:${chainId ?? "unknown"}:${proposalId}`;
}

export function saveProposalMetadata(
  chainId: number | undefined,
  metadata: ProposalMetadata,
): void {
  if (typeof window === "undefined") {
    return;
  }

  window.localStorage.setItem(
    getProposalMetadataStorageKey(chainId, metadata.proposalId),
    JSON.stringify(metadata),
  );
}

export function loadProposalMetadata(
  chainId: number | undefined,
  proposalId?: string,
): ProposalMetadata | undefined {
  if (typeof window === "undefined" || !proposalId) {
    return undefined;
  }

  const rawValue = window.localStorage.getItem(
    getProposalMetadataStorageKey(chainId, proposalId),
  );

  if (!rawValue) {
    return undefined;
  }

  try {
    const parsed = JSON.parse(rawValue) as Partial<ProposalMetadata>;

    if (
      typeof parsed.proposalId === "string" &&
      typeof parsed.title === "string" &&
      typeof parsed.description === "string" &&
      typeof parsed.composedDescription === "string"
    ) {
      return parsed as ProposalMetadata;
    }
  } catch {
    return undefined;
  }

  return undefined;
}
