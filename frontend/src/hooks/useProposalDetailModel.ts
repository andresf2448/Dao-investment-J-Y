import {
  getDaoGovernorContract,
  getGovernanceTokenContract,
} from "@dao/contracts-sdk";
import { useMemo, useState } from "react";
import Swal from "sweetalert2";
import { useBlockNumber, useChainId, useConnection, useReadContracts } from "wagmi";
import type {
  ProposalDetailData,
  ProposalDetailModel,
} from "@/types/models/proposalDetail";
import { useProtocolCapabilities } from "./useProtocolCapabilities";
import {
  formatEstimatedBlockDate,
  formatTokenAmount,
  getTransactionError,
  loadProposalMetadata,
} from "@/utils";
import { getReadContractResult } from "./shared/contractResults";
import { mapGovernorProposalState } from "./shared/governance";
import { resolveOptionalContract } from "./shared/resolveContract";
import useWriteContracts from "./useWriteContracts";

export function useProposalDetailModel(
  proposalId?: string,
): ProposalDetailModel {
  const chainId = useChainId();
  const connection = useConnection();
  const capabilities = useProtocolCapabilities();
  const { data: currentBlock } = useBlockNumber({
    watch: true,
  });
  const governorConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getDaoGovernorContract);
  }, [chainId]);
  const governanceTokenConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getGovernanceTokenContract);
  }, [chainId]);
  const { executeWrite } = useWriteContracts();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const parsedProposalId = useMemo(() => {
    if (!proposalId) {
      return undefined;
    }

    try {
      return BigInt(proposalId);
    } catch {
      return undefined;
    }
  }, [proposalId]);

  const { data: proposalData } = useReadContracts({
    allowFailure: true,
    contracts:
      governorConfig && parsedProposalId !== undefined
        ? [
            {
              abi: governorConfig.abi,
              address: governorConfig.address,
              functionName: "state" as const,
              args: [parsedProposalId],
            },
            {
              abi: governorConfig.abi,
              address: governorConfig.address,
              functionName: "proposalVotes" as const,
              args: [parsedProposalId],
            },
            {
              abi: governorConfig.abi,
              address: governorConfig.address,
              functionName: "proposalSnapshot" as const,
              args: [parsedProposalId],
            },
            {
              abi: governorConfig.abi,
              address: governorConfig.address,
              functionName: "proposalDeadline" as const,
              args: [parsedProposalId],
            },
            {
              abi: governorConfig.abi,
              address: governorConfig.address,
              functionName: "proposalProposer" as const,
              args: [parsedProposalId],
            },
            {
              abi: governorConfig.abi,
              address: governorConfig.address,
              functionName: "proposalDetails" as const,
              args: [parsedProposalId],
            },
          ]
        : [],
    query: {
      enabled: Boolean(governorConfig && parsedProposalId !== undefined),
    },
  });

  const { data: userVotingPowerData } = useReadContracts({
    allowFailure: true,
    contracts:
      governanceTokenConfig && connection.address
        ? [
            {
              abi: governanceTokenConfig.abi,
              address: governanceTokenConfig.address,
              functionName: "getVotes" as const,
              args: [connection.address],
            },
          ]
        : [],
    query: {
      enabled: Boolean(governanceTokenConfig && connection.address),
    },
  });

  const proposalState = mapGovernorProposalState(
    getReadContractResult<number | bigint>(proposalData?.[0]),
  );
  const voteBreakdown =
    getReadContractResult<readonly [bigint, bigint, bigint]>(proposalData?.[1]) ??
    [0n, 0n, 0n];
  const proposalSnapshot =
    getReadContractResult<bigint>(proposalData?.[2]) ?? 0n;
  const proposalDeadline =
    getReadContractResult<bigint>(proposalData?.[3]) ?? 0n;
  const proposalProposer =
    getReadContractResult<string>(proposalData?.[4]) ?? "Unknown proposer";
  const proposalDetails = getReadContractResult<
    readonly [
      readonly string[],
      readonly bigint[],
      readonly string[],
      `0x${string}`,
    ]
  >(proposalData?.[5]);

  const proposalActions = useMemo(() => {
    const targets = proposalDetails?.[0] ?? [];
    const values = proposalDetails?.[1] ?? [];
    const calldatas = proposalDetails?.[2] ?? [];

    return targets.map((target, index) => ({
      target,
      value: (values[index] ?? 0n).toString(),
      calldata: calldatas[index] ?? "0x",
    }));
  }, [proposalDetails]);

  const proposalMetadata = useMemo(
    () => loadProposalMetadata(chainId, proposalId),
    [chainId, proposalId],
  );

  const proposalTitle = useMemo(() => {
    if (proposalMetadata?.title?.trim()) {
      return proposalMetadata.title.trim();
    }

    const actionCount = proposalActions.length;

    return actionCount > 0
      ? `Governance proposal with ${actionCount} action${actionCount === 1 ? "" : "s"}`
      : proposalId
      ? `Governance proposal ${proposalId}`
      : "Governance proposal";
  }, [proposalActions.length, proposalId, proposalMetadata?.title]);

  const proposal: ProposalDetailData = {
    id: proposalId ?? "P-101",
    title: proposalTitle,
    status: proposalState,
    description:
      proposalMetadata?.description?.trim() ||
      "Proposal metadata was not cached by this frontend for this proposal. The governor stores the action payload and description hash onchain, so proposals created elsewhere may not expose the original text here.",
    proposer: proposalProposer,
    executionEta:
      proposalState === "Queued" && proposalDeadline > 0n
        ? formatEstimatedBlockDate({
            targetBlock: proposalDeadline,
            currentBlock,
            chainId,
          })
        : proposalDeadline > 0n
          ? `Block ${proposalDeadline.toString()}`
          : "Unavailable",
    delegatedVotes: formatTokenAmount(
      getReadContractResult<bigint>(userVotingPowerData?.[0]) ?? 0n,
      "GOV",
    ),
    votes: {
      againstVotes: formatTokenAmount(voteBreakdown[0], "GOV"),
      forVotes: formatTokenAmount(voteBreakdown[1], "GOV"),
      abstainVotes: formatTokenAmount(voteBreakdown[2], "GOV"),
    },
    timeline: [
      {
        label: "Snapshot",
        value:
          proposalSnapshot > 0n
            ? `Block ${proposalSnapshot.toString()}`
            : "Unavailable",
      },
      {
        label: "Deadline",
        value:
          proposalDeadline > 0n
            ? `Block ${proposalDeadline.toString()}`
            : "Unavailable",
      },
    ],
    actions: proposalActions,
  };

  const canVote =
    proposal.status === "Active" &&
    parsedProposalId !== undefined &&
    !isSubmitting;
  const canExecuteProposal =
    proposal.status === "Queued" &&
    parsedProposalId !== undefined &&
    !isSubmitting;

  const confirmVoteAction = async (
    voteLabel: string,
    action: "for" | "against" | "abstain",
  ) => {
    if (!canVote) {
      return;
    }

    const confirmation = await Swal.fire({
      title: "Confirm vote",
      text: `You selected "${voteLabel}". Do you want to continue?`,
      icon: "question",
      showCancelButton: true,
      confirmButtonText: "Yes, vote",
      cancelButtonText: "Cancel",
      reverseButtons: true,
    });

    if (!confirmation.isConfirmed) {
      return;
    }

    await submitGovernanceAction(`Voting ${voteLabel.toLowerCase()}`, action);
  };

  const submitGovernanceAction = async (
    title: string,
    action: "for" | "against" | "abstain" | "execute",
  ) => {
    if (!parsedProposalId) {
      await Swal.fire({
        title: "Invalid proposal",
        text: "The proposal identifier could not be resolved.",
        icon: "error",
        confirmButtonText: "OK",
      });
      return;
    }

    if (isSubmitting) {
      return;
    }

    setIsSubmitting(true);

    Swal.fire({
      title,
      text:
        action === "execute"
          ? "Confirm the execution transaction in your wallet."
          : "Confirm the vote transaction in your wallet.",
      allowOutsideClick: false,
      allowEscapeKey: false,
      showConfirmButton: false,
      didOpen: () => {
        Swal.showLoading();
      },
    });

    try {
      const response = await executeWrite({
        functionContract: "getDaoGovernorContract",
        functionName: action === "execute" ? "execute" : "castVote",
        args:
          action === "execute"
            ? [parsedProposalId]
            : [
                parsedProposalId,
                action === "for" ? 0 : action === "against" ? 1 : 2,
              ],
        options: {
          waitForReceipt: true,
        },
      });

      if (response?.receipt?.status !== "success") {
        throw new Error(
          action === "execute"
            ? "The proposal execution did not complete successfully."
            : "The vote transaction did not complete successfully.",
        );
      }

      Swal.close();

      await Swal.fire({
        title:
          action === "execute"
            ? "Proposal executed"
            : "Vote submitted",
        text:
          action === "execute"
            ? "The proposal execution was submitted successfully."
            : "Your vote was cast successfully.",
        icon: "success",
        confirmButtonText: "OK",
      });
    } catch (error) {
      const transactionError = getTransactionError(error);

      Swal.hideLoading();
      Swal.update({
        title: transactionError.title,
        text: transactionError.message,
        icon: "error",
        showConfirmButton: true,
        confirmButtonText: "OK",
        allowOutsideClick: true,
        allowEscapeKey: true,
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  return {
    proposal,
    capabilities,
    canVote,
    canExecuteProposal,
    voteFor: () => confirmVoteAction("Vote For", "for"),
    voteAgainst: () => confirmVoteAction("Vote Against", "against"),
    abstain: () => confirmVoteAction("Abstain", "abstain"),
    executeProposal: () => submitGovernanceAction("Executing proposal", "execute"),
    isSubmitting,
  };
}
