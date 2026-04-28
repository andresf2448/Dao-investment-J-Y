import { useMemo, useState } from "react";
import { parseUnits, type Address } from "viem";
import { useChainId, useReadContracts } from "wagmi";
import Swal from "sweetalert2";
import type {
  TreasuryOperationToken,
  TreasuryOperationsModel,
} from "@/types/models/treasuryOperations";
import { getKnownProtocolAssets } from "@/constants/protocolAssets";
import {
  abiERC20,
  formatAddress,
  getTransactionError,
  isValidAddress,
} from "@/utils";
import { useProtocolCapabilities } from "./useProtocolCapabilities";
import { useProtocolReads } from "./useProtocolReads";
import { getReadContractResult } from "./shared/contractResults";
import useWriteContracts from "./useWriteContracts";

export function useTreasuryOperationsModel(): TreasuryOperationsModel {
  const chainId = useChainId();
  const capabilities = useProtocolCapabilities();
  const { executeWrite } = useWriteContracts();
  const { refetch: refetchGenesisTokens, assetsSupported } = useProtocolReads([
    {
      key: "assetsSupported",
      contract: "getProtocolCoreContract",
      functionName: "getSupportedGenesisTokens",
    },
  ]);

  const knownAssets = useMemo(() => getKnownProtocolAssets(chainId), [chainId]);
  const genesisTokens = useMemo(
    () => ((assetsSupported as readonly Address[] | undefined) ?? []),
    [assetsSupported],
  );

  const tokens = useMemo<TreasuryOperationToken[]>(() => {
    return knownAssets.map((asset) => ({
      symbol: asset.symbol,
      address: asset.address,
      category: genesisTokens.includes(asset.address)
        ? "DAO Asset"
        : "Non-DAO Asset",
      decimals: asset.decimals,
      isKnownAsset: true,
    }));
  }, [genesisTokens, knownAssets]);

  const [tokenAddress, setTokenAddress] = useState<string>(
    "",
  );
  const [amount, setAmount] = useState("");
  const [recipient, setRecipient] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const normalizedTokenAddress = tokenAddress.trim();
  const isTokenAddressValid = isValidAddress(normalizedTokenAddress);

  const knownAssetMeta = useMemo(
    () =>
      knownAssets.find(
        (asset) =>
          asset.address.toLowerCase() === normalizedTokenAddress.toLowerCase(),
      ) ?? null,
    [knownAssets, normalizedTokenAddress],
  );

  const { data: tokenMetadataData } = useReadContracts({
    allowFailure: true,
    contracts:
      isTokenAddressValid && !knownAssetMeta
        ? [
            {
              abi: abiERC20,
              address: normalizedTokenAddress as Address,
              functionName: "symbol" as const,
            },
            {
              abi: abiERC20,
              address: normalizedTokenAddress as Address,
              functionName: "decimals" as const,
            },
          ]
        : [],
    query: {
      enabled: isTokenAddressValid && !knownAssetMeta,
    },
  });

  const tokenSymbol =
    knownAssetMeta?.symbol ??
    getReadContractResult<string>(tokenMetadataData?.[0]) ??
    (isTokenAddressValid
      ? formatAddress(normalizedTokenAddress as Address)
      : "—");
  const tokenDecimals =
    knownAssetMeta?.decimals ??
    Number(getReadContractResult<bigint>(tokenMetadataData?.[1]) ?? 0n);
  const tokenCategory =
    normalizedTokenAddress &&
    genesisTokens.includes(normalizedTokenAddress as Address)
      ? "DAO Asset"
      : "Non-DAO Asset";

  const selectedToken = useMemo<TreasuryOperationToken | null>(() => {
    if (!isTokenAddressValid || normalizedTokenAddress === "" || tokenDecimals < 0) {
      return null;
    }

    return {
      symbol: tokenSymbol,
      address: normalizedTokenAddress as Address,
      category: tokenCategory,
      decimals: tokenDecimals,
      isKnownAsset: Boolean(knownAssetMeta),
    };
  }, [
    isTokenAddressValid,
    knownAssetMeta,
    normalizedTokenAddress,
    tokenCategory,
    tokenDecimals,
    tokenSymbol,
  ]);

  const isAmountValid =
    amount.trim() !== "" &&
    Number.isFinite(Number(amount)) &&
    Number(amount) > 0;
  const isRecipientValid = isValidAddress(recipient.trim());

  const canExecute =
    !!selectedToken &&
    selectedToken.category === "Non-DAO Asset" &&
    capabilities.canWithdrawNonDaoAssets &&
    isAmountValid &&
    isRecipientValid &&
    !isSubmitting;

  const executeWithdrawal = async () => {
    if (!selectedToken || !canExecute) {
      return;
    }

    setIsSubmitting(true);

    Swal.fire({
      title: "Preparing withdrawal",
      text: "Confirm the treasury transaction in your wallet.",
      allowOutsideClick: false,
      allowEscapeKey: false,
      showConfirmButton: false,
      didOpen: () => {
        Swal.showLoading();
      },
    });

    try {
      const parsedAmount = parseUnits(amount, selectedToken.decimals);

      const functionName =
        selectedToken.category === "DAO Asset"
          ? "withdrawDaoERC20"
          : "withdrawNotAssetDaoERC20";

      const response = await executeWrite({
        functionContract: "getTreasuryContract",
        functionName,
        args: [selectedToken.address, recipient.trim() as Address, parsedAmount],
        options: {
          waitForReceipt: true,
        },
      });

      if (response?.receipt?.status !== "success") {
        throw new Error("Treasury withdrawal failed.");
      }

      setTokenAddress("");
      setAmount("");
      setRecipient("");
      await refetchGenesisTokens();
      Swal.close();

      await Swal.fire({
        title: "Withdrawal executed",
        text: `Treasury ${selectedToken.category.toLowerCase()} withdrawal completed successfully.`,
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
    tokens,
    tokenAddress,
    setTokenAddress,
    selectedToken,
    setSelectedToken: (token: TreasuryOperationToken) => {
      setTokenAddress("");
    },
    amount,
    setAmount,
    recipient,
    setRecipient,
    isAmountValid,
    isRecipientValid,
    canExecute,
    isSubmitting,
    capabilities,
    executeWithdrawal,
  };
}
