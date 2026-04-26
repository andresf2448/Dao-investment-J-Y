import { useEffect, useMemo, useState } from "react";
import { getGuardianBondEscrowContract } from "@dao/contracts-sdk";
import { useChainId, useConnection, useReadContracts } from "wagmi";
import { type Address } from "viem";
import Swal from "sweetalert2";

import {
  getGuardianProposalState,
  getGuardianStatus,
  isGuardianContractDetail,
} from "@/helpers";
import type { GuardianMetrics, GuardianState } from "@/types/guardian";
import { GuardianContractStatus } from "@/types/guardian";
import type { GuardiansModel } from "@/types/models/guardians";

import { useProtocolCapabilities } from "./useProtocolCapabilities";
import { useProtocolReads } from "./useProtocolReads";
import {
  type GuardiansProtocolReadContext,
  useGuardiansModelProtocolReadDefinitions,
} from "./definitions/protocolReads";
import useWriteContracts from "./useWriteContracts";
import {
  abiERC20,
  formatTokenAmount,
  getTransactionError,
} from "@/utils";
import { getReadContractResult } from "./shared/contractResults";
import { formatExactTokenAmount } from "./shared/formatting";
import { resolveOptionalContract } from "./shared/resolveContract";

export function useGuardiansModel(): GuardiansModel {
  const chainId = useChainId();
  const capabilities = useProtocolCapabilities();
  const connection = useConnection();
  const { executeWrite } = useWriteContracts();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const [guardianProposalId, setGuardianProposalId] = useState<
    number | undefined
  >(undefined);

  const guardianReadContext = useMemo<GuardiansProtocolReadContext>(
    () => ({
      userAddress: connection.address as Address | undefined,
      proposalId: guardianProposalId,
    }),
    [guardianProposalId, connection.address],
  );

  const {
    minStake,
    totalActiveGuardians,
    statusGuardian,
    balanceBondEscrow,
    refetch,
  } =
    useProtocolReads(
      useGuardiansModelProtocolReadDefinitions,
      guardianReadContext,
    );

  const guardianBondEscrowConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getGuardianBondEscrowContract);
  }, [chainId]);

  const { data: guardianBondEscrowMetadata } = useReadContracts({
    allowFailure: true,
    contracts: guardianBondEscrowConfig
      ? [
          {
            abi: guardianBondEscrowConfig.abi,
            address: guardianBondEscrowConfig.address,
            functionName: "guardianApplicationToken",
          },
        ]
      : [],
    query: {
      enabled: Boolean(guardianBondEscrowConfig),
    },
  });

  const guardianApplicationTokenAddress = getReadContractResult<Address>(
    guardianBondEscrowMetadata?.[0],
  );

  const { data: guardianApplicationTokenMetadata } = useReadContracts({
    allowFailure: true,
    contracts: guardianApplicationTokenAddress
      ? [
          {
            abi: abiERC20,
            address: guardianApplicationTokenAddress,
            functionName: "symbol",
          },
          {
            abi: abiERC20,
            address: guardianApplicationTokenAddress,
            functionName: "decimals",
          },
        ]
      : [],
    query: {
      enabled: Boolean(guardianApplicationTokenAddress),
    },
  });

  const guardianApplicationTokenSymbol =
    getReadContractResult<string>(guardianApplicationTokenMetadata?.[0]) ??
    "tokens";
  const guardianApplicationTokenDecimals =
    getReadContractResult<number>(guardianApplicationTokenMetadata?.[1]) ?? 18;

  const { data: guardianApplicationTokenWalletData } = useReadContracts({
    allowFailure: true,
    contracts:
      guardianApplicationTokenAddress &&
      guardianBondEscrowConfig &&
      connection.address
        ? [
            {
              abi: abiERC20,
              address: guardianApplicationTokenAddress,
              functionName: "balanceOf",
              args: [connection.address as Address],
            },
            {
              abi: abiERC20,
              address: guardianApplicationTokenAddress,
              functionName: "allowance",
              args: [
                connection.address as Address,
                guardianBondEscrowConfig.address,
              ],
            },
          ]
        : [],
    query: {
      enabled: Boolean(
        guardianApplicationTokenAddress &&
          guardianBondEscrowConfig &&
          connection.address,
      ),
    },
  });

  const guardianApplicationTokenBalance =
    getReadContractResult<bigint>(guardianApplicationTokenWalletData?.[0]);
  const guardianApplicationTokenAllowance =
    getReadContractResult<bigint>(guardianApplicationTokenWalletData?.[1]);

  const requiredStakeAmount =
    typeof minStake === "bigint" ? minStake : undefined;
  const requiredStakeDisplay = requiredStakeAmount
    ? formatExactTokenAmount(
        requiredStakeAmount,
        guardianApplicationTokenDecimals,
        guardianApplicationTokenSymbol,
      )
    : "0 Tokens";

  const guardianDetail = isGuardianContractDetail(statusGuardian)
    ? statusGuardian
    : undefined;
  const hasRequiredStake =
    typeof requiredStakeAmount === "bigint" &&
    typeof guardianDetail?.balance === "bigint"
      ? guardianDetail.balance >= requiredStakeAmount
      : false;

  const state: GuardianState = {
    status: getGuardianStatus(guardianDetail?.status),
    requiredStake: requiredStakeDisplay,
    bondedAmount:
      typeof guardianDetail?.balance === "bigint"
        ? formatTokenAmount(
            guardianDetail.balance,
            guardianApplicationTokenSymbol,
            guardianApplicationTokenDecimals,
          )
        : "0",
    proposalState: getGuardianProposalState(guardianDetail?.status),
    canOperate: guardianDetail?.status === GuardianContractStatus.Active,
  };

  const hasPendingApplication = guardianDetail?.status === GuardianContractStatus.Pending ||
    guardianDetail?.status === GuardianContractStatus.Active;

  const metrics: GuardianMetrics = {
    activeGuardians: totalActiveGuardians ? Number(totalActiveGuardians) : 0,
    // TODO: pendingApplications -> graph o indexación de propuestas pendientes tipo guardian
    pendingApplications: 0,
    escrowBalance:
      typeof balanceBondEscrow === "bigint"
        ? formatTokenAmount(
            balanceBondEscrow,
            guardianApplicationTokenSymbol,
            guardianApplicationTokenDecimals,
          )
        : "0",
    escrowCoverage: !connection.address
      ? "Connect Wallet"
      : hasRequiredStake
        ? "Bonded"
        : "Below Required Stake",
  };

  const approveGuardianStake = async () => {
    if (!guardianApplicationTokenAddress || !guardianBondEscrowConfig || !requiredStakeAmount) {
      return undefined;
    }

    return await executeWrite({
      abi: abiERC20,
      address: guardianApplicationTokenAddress,
      functionName: "approve",
      args: [guardianBondEscrowConfig.address, requiredStakeAmount],
      options: {
        waitForReceipt: true,
      },
    });
  };

  const submitGuardianApplication = async () => {
    return await executeWrite({
      functionName: "applyGuardian",
      functionContract: "getGuardianAdministratorContract",
      options: {
        waitForReceipt: true,
      },
    });
  };

  const applicationGuardian = async () => {
    if (!connection.address) {
      await Swal.fire({
        title: "Wallet required",
        text: "Connect your wallet before submitting a guardian application.",
        icon: "warning",
        confirmButtonText: "OK",
      });
      return;
    }

    if (isSubmitting) {
      return;
    }

    if (!requiredStakeAmount) {
      await Swal.fire({
        title: "Application unavailable",
        text: "The guardian stake requirement could not be loaded. Please try again in a moment.",
        icon: "error",
        confirmButtonText: "OK",
      });
      return;
    }

    if (
      typeof guardianApplicationTokenBalance === "bigint" &&
      guardianApplicationTokenBalance < requiredStakeAmount
    ) {
      await Swal.fire({
        title: "Insufficient balance",
        text: "You do not have enough balance to apply as a guardian.",
        icon: "error",
        confirmButtonText: "OK",
      });
      return;
    }

    if (!guardianApplicationTokenAddress || !guardianBondEscrowConfig) {
      await Swal.fire({
        title: "Application unavailable",
        text: "The guardian bond token configuration could not be loaded. Please try again in a moment.",
        icon: "error",
        confirmButtonText: "OK",
      });
      return;
    }

    setIsSubmitting(true);

    Swal.fire({
      title: "Preparing guardian approval",
      text: "Please confirm the approval transaction in your wallet.",
      allowOutsideClick: false,
      allowEscapeKey: false,
      showConfirmButton: false,
      didOpen: () => {
        Swal.showLoading();
      },
    });

    try {
      if (
        typeof guardianApplicationTokenAllowance !== "bigint" ||
        guardianApplicationTokenAllowance < requiredStakeAmount
      ) {
        const approvalResponse = await approveGuardianStake();

        if (!approvalResponse || !("receipt" in approvalResponse)) {
          throw new Error("The approval transaction was not completed.");
        }

        if (approvalResponse.receipt?.status !== "success") {
          throw new Error("The approval transaction did not complete successfully.");
        }

        Swal.update({
          title: "Submitting guardian application",
          text: "Approval confirmed. Please confirm the guardian application in your wallet.",
        });
      } else {
        Swal.update({
          title: "Submitting guardian application",
          text: "Allowance already available. Please confirm the guardian application in your wallet.",
        });
      }

      const response = await submitGuardianApplication();

      if (response?.receipt?.status === "success") {
        Swal.update({
          title: "Refreshing guardian data",
          text: "The application succeeded. Updating guardian state and metrics.",
        });

        await refetch();
        Swal.close();

        await Swal.fire({
          title: "Application submitted",
          text: "Your guardian application was sent successfully.",
          icon: "success",
          confirmButtonText: "OK",
        });
        return;
      }

      throw new Error("The transaction did not complete successfully.");
    } catch (error) {
      const transactionError = getTransactionError(error);

      if (transactionError.technicalDetails) {
        console.error("[guardians] transaction error", {
          code: transactionError.code,
          technicalDetails: transactionError.technicalDetails,
          error,
        });
      }

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

  useEffect(() => {
    if (guardianDetail?.proposalId != null) {
      setGuardianProposalId(Number(guardianDetail.proposalId));
    } else {
      setGuardianProposalId(undefined);
    }
  }, [guardianDetail]);

  // TODO: Reemplace con datos reales con graph o indexación de eventos.
  return {
    state,
    metrics,
    capabilities,
    isSubmitting,
    hasPendingApplication,
    applicationGuardian,
  };
}
