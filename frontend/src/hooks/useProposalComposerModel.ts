import {
  getDaoGovernorContract,
  getGovernanceTokenContract,
} from "@dao/contracts-sdk";
import { useMemo, useState } from "react";
import { useChainId, useConnection, useReadContracts } from "wagmi";
import type { Address } from "viem";
import Swal from "sweetalert2";
import { parseEventLogs } from "viem";
import type {
  ProposalComposerModel,
} from "@/types/models/proposalComposer";
import { useProtocolCapabilities } from "./useProtocolCapabilities";
import { getReadContractResult } from "./shared/contractResults";
import { resolveOptionalContract } from "./shared/resolveContract";
import {
  formatTokenAmount,
  getTransactionError,
  isValidAddress,
  saveProposalMetadata,
} from "@/utils";
import useWriteContracts from "./useWriteContracts";
import {
  createEmptyProposalAction,
  isValidProposalCalldata,
  isValidProposalExecutionValue,
} from "./shared/proposalComposer";

export function useProposalComposerModel(): ProposalComposerModel {
  const chainId = useChainId();
  const capabilities = useProtocolCapabilities();
  const connection = useConnection();
  const { executeWrite } = useWriteContracts();
  const governorConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getDaoGovernorContract);
  }, [chainId]);
  const governanceTokenConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getGovernanceTokenContract);
  }, [chainId]);

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [actions, setActions] = useState([createEmptyProposalAction()]);
  const [delegateAddress, setDelegateAddress] = useState("");

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isDelegatingVotes, setIsDelegatingVotes] = useState(false);

  const { data: thresholdData } = useReadContracts({
    allowFailure: true,
    contracts: governorConfig
      ? [
          {
            abi: governorConfig.abi,
            address: governorConfig.address,
            functionName: "proposalThreshold" as const,
          },
        ]
      : [],
    query: {
      enabled: Boolean(governorConfig),
    },
  });

  const { data: votingPowerData } = useReadContracts({
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

  const votingPowerValue =
    getReadContractResult<bigint>(votingPowerData?.[0]) ?? 0n;
  const proposalThresholdValue =
    getReadContractResult<bigint>(thresholdData?.[0]) ?? 0n;

  const votingPower = formatTokenAmount(votingPowerValue, "GOV");
  const proposalThreshold = formatTokenAmount(proposalThresholdValue, "GOV");
  const meetsThreshold = votingPowerValue >= proposalThresholdValue;
  const normalizedDelegateAddress = delegateAddress.trim();
  const isDelegateAddressValid =
    normalizedDelegateAddress !== "" &&
    isValidAddress(normalizedDelegateAddress);
  const delegateAddressError =
    normalizedDelegateAddress !== "" && !isDelegateAddressValid
      ? "Enter a valid delegate address."
      : undefined;
  const canDelegateVotes =
    Boolean(connection.address) &&
    isDelegateAddressValid &&
    !isDelegatingVotes;
  const isTitleValid = title.trim().length >= 5;
  const isDescriptionValid = description.trim().length >= 10;
  const areActionsValid = actions.every((action) => {
    return (
      isValidAddress(action.target.trim()) &&
      isValidProposalExecutionValue(action.value) &&
      isValidProposalCalldata(action.calldata)
    );
  });
  const canSubmitProposal =
    Boolean(connection.address) &&
    meetsThreshold &&
    isTitleValid &&
    isDescriptionValid &&
    actions.length > 0 &&
    areActionsValid &&
    !isSubmitting;

  const addAction = () => {
    setActions((prev) => [...prev, createEmptyProposalAction()]);
  };

  const updateAction = (
    id: string,
    field: "target" | "value" | "calldata",
    value: string,
  ) => {
    setActions((prev) =>
      prev.map((action) =>
        action.id === id ? { ...action, [field]: value } : action
      )
    );
  };

  const removeAction = (id: string) => {
    setActions((prev) => prev.filter((action) => action.id !== id));
  };

  const delegateVotes = async () => {
    if (!canDelegateVotes) {
      return;
    }

    setIsDelegatingVotes(true);

    Swal.fire({
      title: "Delegating voting power",
      text: "Confirm the delegation transaction in your wallet.",
      allowOutsideClick: false,
      allowEscapeKey: false,
      showConfirmButton: false,
      didOpen: () => {
        Swal.showLoading();
      },
    });

    try {
      const response = await executeWrite({
        functionContract: "getGovernanceTokenContract",
        functionName: "delegate",
        args: [normalizedDelegateAddress as Address],
        options: {
          waitForReceipt: true,
        },
      });

      if (response?.receipt?.status !== "success") {
        throw new Error("Vote delegation failed.");
      }

      setDelegateAddress("");
      Swal.close();

      await Swal.fire({
        title: "Votes delegated",
        text: "Your governance voting power delegation was updated successfully.",
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
      setIsDelegatingVotes(false);
    }
  };

  const submitProposal = async () => {
    if (!canSubmitProposal || isSubmitting) {
      return;
    }

    const confirmation = await Swal.fire({
      title: "Submit proposal",
      text: "Confirm the proposal submission transaction in your wallet.",
      icon: "question",
      showCancelButton: true,
      confirmButtonText: "Yes, submit",
      cancelButtonText: "Cancel",
      reverseButtons: true,
    });

    if (!confirmation.isConfirmed) {
      return;
    }

    setIsSubmitting(true);

    Swal.fire({
      title: "Submitting proposal",
      text: "Confirm the proposal submission transaction in your wallet.",
      allowOutsideClick: false,
      allowEscapeKey: false,
      showConfirmButton: false,
      didOpen: () => {
        Swal.showLoading();
      },
    });

    const targets = actions.map((action) => action.target.trim() as Address);
    const values = actions.map((action) => BigInt(action.value.trim()));
    const calldatas = actions.map(
      (action) => action.calldata.trim() as `0x${string}`,
    );
    const proposalDescription = [title.trim(), description.trim()]
      .filter(Boolean)
      .join("\n\n");

    try {
      const response = await executeWrite({
        functionContract: "getDaoGovernorContract",
        functionName: "propose",
        args: [targets, values, calldatas, proposalDescription],
        options: {
          waitForReceipt: true,
        },
      });

      if (response?.receipt?.status !== "success") {
        throw new Error("Proposal submission failed.");
      }

      const proposalCreatedEvent = governorConfig
        ? parseEventLogs({
            abi: governorConfig.abi,
            logs: response.receipt?.logs ?? [],
            eventName: "ProposalCreated",
          })?.[0]
        : undefined;
      const proposalId = proposalCreatedEvent?.args?.proposalId?.toString();
      const submittedTitle = title.trim();
      const submittedDescription = description.trim();
      const composedDescription = [submittedTitle, submittedDescription]
        .filter(Boolean)
        .join("\n\n");

      if (proposalId) {
        saveProposalMetadata(chainId, {
          proposalId,
          title: submittedTitle,
          description: submittedDescription,
          composedDescription,
        });
      }

      setTitle("");
      setDescription("");
      setActions([createEmptyProposalAction()]);
      Swal.close();

      await Swal.fire({
        title: "Proposal submitted",
        text: "Your governance proposal was sent successfully.",
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
    title,
    setTitle,
    description,
    setDescription,
    actions,
    addAction,
    updateAction,
    removeAction,
    votingPower,
    proposalThreshold,
    meetsThreshold,
    delegateAddress,
    setDelegateAddress,
    delegateAddressError,
    canDelegateVotes,
    isDelegatingVotes,
    delegateVotes,
    submitProposal,
    canSubmitProposal,
    isSubmitting,
    capabilities,
  };
}
