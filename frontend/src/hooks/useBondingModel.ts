import { useMemo, useState } from "react";
import { isAddress, type Address } from "viem";
import { useChainId, useConnection } from "wagmi";
import Swal from "sweetalert2";
import { getGenesisBondingContract } from "@dao/contracts-sdk";

import { calculateEstimatedTokens, parseBondingTokenAmount } from "@/helpers";
import {
  bondingProtocolReadDefinitions,
  BondingProtocolReadContext,
} from "@/hooks/definitions/protocolReads";
import type {
  BondingAsset,
  BondingModel,
  BondingPosition,
  BondingState,
} from "@/types/models/bonding";
import {
  abiERC20,
  formatTokenAmount,
  getContractNameByNetwork,
  getTransactionError,
} from "@/utils";
import useWriteContracts from "./useWriteContracts";
import { useProtocolReads } from "./useProtocolReads";
import { useProtocolCapabilities } from "./useProtocolCapabilities";
import { resolveOptionalContract } from "./shared/resolveContract";

export function useBondingModel(): BondingModel {
  const chainId = useChainId();
  const connection = useConnection();

  const capabilities = useProtocolCapabilities();
  const { executeWrite } = useWriteContracts();
  const bondingReadContext = useMemo<BondingProtocolReadContext>(
    () => ({
      governanceToken: connection.address as Address,
    }),
    [connection.address],
  );

  const bondingConfig = useMemo<ReturnType<
    typeof getGenesisBondingContract
  > | null>(() => {
    return resolveOptionalContract(chainId, getGenesisBondingContract);
  }, [chainId]);

  const {
    isFinalized,
    rate,
    totalDistributed,
    assetsSupported,
    governanceTokenWalletBalance,
    refetch,
  } = useProtocolReads(bondingProtocolReadDefinitions, bondingReadContext);
console.log("===============", assetsSupported);

  const [selectedAssetAddress, setSelectedAssetAddress] =
    useState<Address | null>(null);
  const [amount, setAmount] = useState("");
  const [sweepToken, setSweepToken] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const isAmountValid =
    amount.trim() !== "" &&
    Number.isFinite(Number(amount)) &&
    Number(amount) > 0;
  const amountError =
    amount.trim() !== "" && !isAmountValid
      ? "Enter a numeric amount greater than 0."
      : undefined;

  const assets = useMemo<BondingAsset[]>(() => {
    const supportedAssets = (assetsSupported as Address[] | undefined) ?? [];

    return supportedAssets.map((assetAddress) => ({
      symbol: getContractNameByNetwork(chainId, assetAddress),
      address: assetAddress,
    }));
  }, [assetsSupported, chainId]);

  const selectedAsset = useMemo<BondingAsset | null>(() => {
    if (assets.length === 0) {
      return null;
    }

    if (!selectedAssetAddress) {
      return assets[0];
    }

    return (
      assets.find((asset) => asset.address === selectedAssetAddress) ??
      assets[0]
    );
  }, [assets, selectedAssetAddress]);

  const state = useMemo<BondingState>(() => {
    const finalized = (isFinalized as boolean) || false;

    return {
      isFinalized: finalized,
      rate: (Number(rate) as number) || 100,
      totalDistributed: formatTokenAmount(
        (totalDistributed as bigint | undefined) ?? 0n,
        "GOV",
      ),
      bondingStatus: finalized ? "Finalized" : "Active",
    };
  }, [isFinalized, rate, totalDistributed]);

  const estimatedTokens = useMemo(() => {
    return calculateEstimatedTokens(amount, state.rate);
  }, [amount, state.rate]);
  const sweepTokenError =
    sweepToken.trim() !== "" && !isAddress(sweepToken.trim())
      ? "Enter a valid token address."
      : undefined;

  const canBuy =
    capabilities.canBuyGovernanceTokens &&
    !state.isFinalized &&
    !isSubmitting &&
    !!selectedAsset &&
    isAmountValid;

  const canSweep =
    capabilities.canSweepBondingTokens &&
    !isSubmitting &&
    sweepToken.trim() !== "" &&
    !sweepTokenError;

  const setSelectedAsset = (asset: BondingAsset) => {
    setSelectedAssetAddress(asset.address);
  };

  const approveToken = async (parsedAmount: bigint) => {
    if (!selectedAsset || !bondingConfig) return;

    return await executeWrite({
      abi: abiERC20,
      address: selectedAsset.address,
      functionName: "approve",
      args: [bondingConfig.address, parsedAmount],
      options: {
        waitForReceipt: true,
      },
    });
  };

  const createTransactionDetails = async (parsedAmount: bigint) => {
    if (!selectedAsset || !bondingConfig) return;

    return await executeWrite({
      functionContract: "getGenesisBondingContract",
      functionName: "buy",
      args: [selectedAsset.address, parsedAmount],
      options: {
        waitForReceipt: true,
      },
    });
  };

  const createTransaction = async () => {
    if (!selectedAsset || !bondingConfig || !canBuy) return;

    const parsedAmount = parseBondingTokenAmount(amount);

    if (!parsedAmount) {
      Swal.fire({
        title: "Error",
        text: "Invalid amount",
        icon: "error",
        confirmButtonText: "Cool",
      });
      return;
    }

    setIsSubmitting(true);

    Swal.fire({
      title: "Preparing approval",
      text: "Please confirm the approval transaction in your wallet.",
      allowOutsideClick: false,
      allowEscapeKey: false,
      showConfirmButton: false,
      didOpen: () => {
        Swal.showLoading();
      },
    });

    try {
      const response = await approveToken(parsedAmount);

      if (!response || !("receipt" in response)) {
        throw new Error("The approval transaction was not completed.");
      }

      if (response.receipt?.status === "success") {
        Swal.update({
          title: "Purchasing governance tokens",
          text: "Approval confirmed. Waiting for the purchase transaction receipt.",
        });

        const buyResponse = await createTransactionDetails(parsedAmount);

        if (buyResponse?.receipt?.status === "success") {
          Swal.update({
            title: "Refreshing bonding data",
            text: "The transaction succeeded. Updating balances and metrics.",
          });

          setAmount("");
          await refetch();
          Swal.close();

          await Swal.fire({
            title: "Purchase successful",
            text: "Bonding balances and metrics have been updated.",
            icon: "success",
            confirmButtonText: "OK",
          });
          return;
        }
      }
      throw new Error("The purchase transaction did not complete successfully.");
    } catch (error) {
      const transactionError = getTransactionError(error);

      if (transactionError.technicalDetails) {
        console.error("[bonding] transaction error", {
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

  const governanceBalance =
    typeof governanceTokenWalletBalance === "bigint"
      ? formatTokenAmount(governanceTokenWalletBalance, "GOV")
      : "0 GOV";

  const sweep = async () => {
    if (!sweepToken || !bondingConfig || !capabilities.canSweepBondingTokens) return;

    const parsedToken = sweepToken.trim();

    if (!isAddress(parsedToken)) {
      Swal.fire({
        title: "Invalid token address",
        text: "Please enter a valid ERC20 token address to sweep.",
        icon: "error",
        confirmButtonText: "OK",
      });
      return;
    }

    setIsSubmitting(true);
    Swal.fire({
      title: "Sweeping token",
      text: "Please confirm the sweep transaction in your wallet.",
      allowOutsideClick: false,
      allowEscapeKey: false,
      showConfirmButton: false,
      didOpen: () => {
        Swal.showLoading();
      },
    });

    try {
      const response = await executeWrite({
        abi: bondingConfig.abi,
        address: bondingConfig.address,
        functionName: "sweep",
        args: [parsedToken as Address],
        options: { waitForReceipt: true },
      });

      if (!response || response.receipt?.status !== "success") {
        throw new Error("Sweep transaction failed.");
      }

      await refetch();
      Swal.close();

      await Swal.fire({
        title: "Sweep successful",
        text: "The token has been swept to the bonding treasury.",
        icon: "success",
        confirmButtonText: "OK",
      });
      setSweepToken("");
    } catch (error) {
      const transactionError = getTransactionError(error);
      Swal.hideLoading();
      Swal.update({
        title: transactionError.title,
        text: transactionError.message,
        icon: "error",
        showConfirmButton: true,
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  const estimatedValue =
    typeof governanceTokenWalletBalance === "bigint" && state.rate > 0
      ? `$${(Number(governanceTokenWalletBalance) / 10 ** 18 / state.rate).toFixed(2)}`
      : "$0.00";

  const position: BondingPosition = {
    governanceBalance,
    estimatedValue,
  };

  return {
    assets,
    selectedAsset,
    setSelectedAsset,
    amount,
    setAmount,
    isAmountValid,
    amountError,
    canBuy,
    isSubmitting,
    estimatedTokens,
    state,
    position,
    capabilities,
    createTransaction,
    sweepToken,
    setSweepToken,
    hasSweepRole: capabilities.canSweepBondingTokens,
    sweepTokenError,
    canSweep,
    sweep,
  };
}