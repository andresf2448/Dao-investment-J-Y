import {
  addresses,
  getProtocolCoreContract,
  getRiskManagerContract,
  getVaultRegistryContract,
} from "@dao/contracts-sdk";
import { useMemo, useState } from "react";
import { useChainId, useConnection, useReadContracts } from "wagmi";
import { encodeAbiParameters } from "viem";
import type { Address } from "viem";
import type {
  VaultDetailControls,
  VaultDetailData,
  VaultDetailModel,
  VaultDetailPosition,
} from "@/types/models/vaultDetail";
import { useProtocolCapabilities } from "./useProtocolCapabilities";
import Swal from "sweetalert2";
import {
  abiERC20,
  formatAddress,
  formatTokenAmount,
  getTransactionError,
  isValidAddress,
  parseTimestamp,
  parseTokenAmount,
} from "@/utils";
import { getReadContractResult } from "./shared/contractResults";
import type { VaultRegistryDetail } from "./shared/contractTypes";
import { resolveOptionalContract } from "./shared/resolveContract";
import useWriteContracts from "./useWriteContracts";

const vaultAbi = [
  {
    type: "function",
    name: "decimals",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
  },
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "totalAssets",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "maxWithdraw",
    stateMutability: "view",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "maxRedeem",
    stateMutability: "view",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "previewRedeem",
    stateMutability: "view",
    inputs: [{ name: "shares", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "previewMint",
    stateMutability: "view",
    inputs: [{ name: "shares", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "deposit",
    stateMutability: "nonpayable",
    inputs: [
      { name: "assets", type: "uint256" },
      { name: "receiver", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "mint",
    stateMutability: "nonpayable",
    inputs: [
      { name: "shares", type: "uint256" },
      { name: "receiver", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "withdraw",
    stateMutability: "nonpayable",
    inputs: [
      { name: "assets", type: "uint256" },
      { name: "receiver", type: "address" },
      { name: "owner", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "redeem",
    stateMutability: "nonpayable",
    inputs: [
      { name: "shares", type: "uint256" },
      { name: "receiver", type: "address" },
      { name: "owner", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "executeStrategy",
    stateMutability: "nonpayable",
    inputs: [
      { name: "adapter", type: "address" },
      { name: "data", type: "bytes" },
    ],
    outputs: [],
  },
] as const;

export function useVaultDetailModel(vaultAddress?: string): VaultDetailModel {
  const chainId = useChainId();
  const capabilities = useProtocolCapabilities();
  const connection = useConnection();
  const { executeWrite } = useWriteContracts();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const resolvedVaultAddress = useMemo(
    () =>
      vaultAddress && isValidAddress(vaultAddress)
        ? (vaultAddress as Address)
        : undefined,
    [vaultAddress],
  );

  const vaultRegistryConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getVaultRegistryContract);
  }, [chainId]);

  const protocolCoreConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getProtocolCoreContract);
  }, [chainId]);

  const riskManagerConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getRiskManagerContract);
  }, [chainId]);

  const { data: registryAndControlData, refetch: refetchRegistryAndControl } = useReadContracts({
    allowFailure: true,
    contracts:
      resolvedVaultAddress &&
      vaultRegistryConfig &&
      protocolCoreConfig &&
      riskManagerConfig
        ? [
            {
              abi: vaultRegistryConfig.abi,
              address: vaultRegistryConfig.address,
              functionName: "getVaultDetail",
              args: [resolvedVaultAddress],
            },
            {
              abi: protocolCoreConfig.abi,
              address: protocolCoreConfig.address,
              functionName: "isVaultDepositsPaused",
            },
            {
              abi: riskManagerConfig.abi,
              address: riskManagerConfig.address,
              functionName: "executionPaused",
            },
          ]
        : [],
    query: {
      enabled: Boolean(
        resolvedVaultAddress &&
          vaultRegistryConfig &&
          protocolCoreConfig &&
          riskManagerConfig,
      ),
    },
  });

  const vaultDetail = getReadContractResult<VaultRegistryDetail>(
    registryAndControlData?.[0],
  );
  const isVaultDepositsPaused =
    getReadContractResult<boolean>(registryAndControlData?.[1]) ?? false;
  const isExecutionPaused =
    getReadContractResult<boolean>(registryAndControlData?.[2]) ?? false;

  const { data: assetMetadataData, refetch: refetchAssetMetadata } = useReadContracts({
    allowFailure: true,
    contracts: vaultDetail?.asset
      ? [
          {
            abi: abiERC20,
            address: vaultDetail.asset,
            functionName: "symbol",
          },
          {
            abi: abiERC20,
            address: vaultDetail.asset,
            functionName: "decimals",
          },
        ]
      : [],
    query: {
      enabled: Boolean(vaultDetail?.asset),
    },
  });

  const assetSymbol =
    getReadContractResult<string>(assetMetadataData?.[0]) ??
    (vaultDetail?.asset ? formatAddress(vaultDetail.asset) : "—");
  const assetDecimals =
    getReadContractResult<number>(assetMetadataData?.[1]) ?? 18;

  const { data: assetBalanceData, refetch: refetchAssetBalance } = useReadContracts({
    allowFailure: true,
    contracts:
      vaultDetail?.asset && connection.address
        ? [
            {
              abi: abiERC20,
              address: vaultDetail.asset,
              functionName: "balanceOf",
              args: [connection.address as Address],
            },
          ]
        : [],
    query: {
      enabled: Boolean(vaultDetail?.asset && connection.address),
    },
  });

  const depositAssetBalanceValue =
    getReadContractResult<bigint>(assetBalanceData?.[0]) ?? 0n;
  const depositAssetBalance = formatTokenAmount(
    depositAssetBalanceValue,
    assetSymbol === "—" ? undefined : assetSymbol,
    assetDecimals,
  );
  const hasDepositAssetBalance = depositAssetBalanceValue > 0n;

  const { data: vaultAccountData, refetch: refetchVaultAccountData } = useReadContracts({
    allowFailure: true,
    contracts:
      resolvedVaultAddress && connection.address
        ? [
            {
              abi: vaultAbi,
              address: resolvedVaultAddress,
              functionName: "decimals",
            },
            {
              abi: vaultAbi,
              address: resolvedVaultAddress,
              functionName: "balanceOf",
              args: [connection.address as Address],
            },
            {
              abi: vaultAbi,
              address: resolvedVaultAddress,
              functionName: "maxWithdraw",
              args: [connection.address as Address],
            },
            {
              abi: vaultAbi,
              address: resolvedVaultAddress,
              functionName: "maxRedeem",
              args: [connection.address as Address],
            },
          ]
        : resolvedVaultAddress
          ? [
              {
                abi: vaultAbi,
                address: resolvedVaultAddress,
                functionName: "decimals",
              },
            ]
          : [],
    query: {
      enabled: Boolean(resolvedVaultAddress),
    },
  });

  const { data: vaultTotalAssetsData, refetch: refetchVaultTotalAssets } = useReadContracts({
    allowFailure: true,
    contracts: resolvedVaultAddress
      ? [
          {
            abi: vaultAbi,
            address: resolvedVaultAddress,
            functionName: "totalAssets",
          },
        ]
      : [],
    query: {
      enabled: Boolean(resolvedVaultAddress),
    },
  });

  const vaultDecimals = getReadContractResult<number>(vaultAccountData?.[0]) ?? assetDecimals;
  const mintedSharesValue = getReadContractResult<bigint>(vaultAccountData?.[1]) ?? 0n;
  const maxWithdrawValue = getReadContractResult<bigint>(vaultAccountData?.[2]) ?? 0n;
  const maxRedeemValue = getReadContractResult<bigint>(vaultAccountData?.[3]) ?? 0n;
  const totalAssetsValue = getReadContractResult<bigint>(vaultTotalAssetsData?.[0]) ?? 0n;

  const { data: previewRedeemData, refetch: refetchPreviewRedeem } = useReadContracts({
    allowFailure: true,
    contracts:
      resolvedVaultAddress && connection.address
        ? [
            {
              abi: vaultAbi,
              address: resolvedVaultAddress,
              functionName: "previewRedeem",
              args: [mintedSharesValue],
            },
          ]
        : [],
    query: {
      enabled: Boolean(resolvedVaultAddress && connection.address),
    },
  });

  const depositedAssetsValue =
    getReadContractResult<bigint>(previewRedeemData?.[0]) ?? 0n;

  const aaveAdapterAddress = useMemo(
    () =>
      chainId
        ? addresses[chainId as keyof typeof addresses]?.aaveV3Adapter
        : undefined,
    [chainId],
  );

  const refreshVaultData = async () => {
    await Promise.allSettled([
      refetchRegistryAndControl?.(),
      refetchAssetMetadata?.(),
      refetchAssetBalance?.(),
      refetchVaultAccountData?.(),
      refetchPreviewRedeem?.(),
    ]);
  };

  const approveAssetForVault = async (amount: bigint) => {
    if (!vaultDetail?.asset || !resolvedVaultAddress) return;

    return executeWrite({
      abi: abiERC20,
      address: vaultDetail.asset,
      functionName: "approve",
      args: [resolvedVaultAddress, amount],
      options: { waitForReceipt: true },
    });
  };

  const executeVaultTransaction = async (
    title: string,
    description: string,
    transaction: () => Promise<unknown>,
  ): Promise<boolean> => {
    setIsSubmitting(true);

    Swal.fire({
      title,
      text: description,
      allowOutsideClick: false,
      allowEscapeKey: false,
      showConfirmButton: false,
      didOpen: () => {
        Swal.showLoading();
      },
    });

    try {
      const response = await transaction();
      const typedResponse = response as
        | { receipt?: { status?: string } }
        | undefined;

      if (!typedResponse || typedResponse.receipt?.status !== "success") {
        throw new Error(`${title} transaction failed.`);
      }

      await refreshVaultData();
      Swal.close();

      await Swal.fire({
        title: `${title} successful`,
        text: "The vault state has been updated.",
        icon: "success",
        confirmButtonText: "OK",
      });
      return true;
    } catch (error) {
      const transactionError = getTransactionError(error);
      Swal.hideLoading();
      Swal.update({
        title: transactionError.title,
        text: transactionError.message,
        icon: "error",
        showConfirmButton: true,
      });
      return false;
    } finally {
      setIsSubmitting(false);
    }
  };

  const deposit = async (amount: string): Promise<boolean> => {
    if (!resolvedVaultAddress || !connection.address || !vaultDetail?.asset) return false;

    const parsedAmount = parseTokenAmount(amount, assetDecimals);
    if (parsedAmount <= 0n) return false;

    return executeVaultTransaction(
      "Deposit assets",
      "Confirm the deposit transaction in your wallet.",
      async () => {
        const approval = await approveAssetForVault(parsedAmount);

        if (!approval || !("receipt" in approval) || approval.receipt?.status !== "success") {
          throw new Error("Token approval failed.");
        }

        return executeWrite({
          abi: vaultAbi,
          address: resolvedVaultAddress,
          functionName: "deposit",
          args: [parsedAmount, connection.address as Address],
          options: { waitForReceipt: true },
        });
      },
    );
  };

  const mint = async (amount: string): Promise<boolean> => {
    if (!resolvedVaultAddress || !connection.address || !vaultDetail?.asset) return false;

    const parsedShares = parseTokenAmount(amount, vaultDecimals);
    if (parsedShares <= 0n) return false;

    return executeVaultTransaction(
      "Mint shares",
      "Confirm the mint transaction in your wallet.",
      async () => {
        const approval = await approveAssetForVault(parsedShares);

        if (!approval || !("receipt" in approval) || approval.receipt?.status !== "success") {
          throw new Error("Token approval failed.");
        }

        return executeWrite({
          abi: vaultAbi,
          address: resolvedVaultAddress,
          functionName: "mint",
          args: [parsedShares, connection.address as Address],
          options: { waitForReceipt: true },
        });
      },
    );
  };

  const withdraw = async (amount: string): Promise<boolean> => {
    if (!resolvedVaultAddress || !connection.address) return false;

    const parsedAmount = parseTokenAmount(amount, assetDecimals);
    if (parsedAmount <= 0n) return false;

    return executeVaultTransaction(
      "Withdraw assets",
      "Confirm the withdraw transaction in your wallet.",
      async () =>
        executeWrite({
          abi: vaultAbi,
          address: resolvedVaultAddress,
          functionName: "withdraw",
          args: [parsedAmount, connection.address as Address, connection.address as Address],
          options: { waitForReceipt: true },
        }),
    );
  };

  const redeem = async (amount: string): Promise<boolean> => {
    if (!resolvedVaultAddress || !connection.address) return false;

    const parsedShares = parseTokenAmount(amount, vaultDecimals);
    if (parsedShares <= 0n) return false;

    return executeVaultTransaction(
      "Redeem shares",
      "Confirm the redeem transaction in your wallet.",
      async () =>
        executeWrite({
          abi: vaultAbi,
          address: resolvedVaultAddress,
          functionName: "redeem",
          args: [parsedShares, connection.address as Address, connection.address as Address],
          options: { waitForReceipt: true },
        }),
    );
  };

  const executeStrategy = async (): Promise<boolean> => {
    if (!resolvedVaultAddress || !aaveAdapterAddress) {
      await Swal.fire({
        title: "Strategy execution unavailable",
        text: "No strategy adapter is configured for this network.",
        icon: "warning",
        confirmButtonText: "OK",
      });
      return false;
    }

    if (maxWithdrawValue <= 0n) {
      await Swal.fire({
        title: "No assets available",
        text: "There are no withdrawable assets available to deploy through the strategy.",
        icon: "warning",
        confirmButtonText: "OK",
      });
      return false;
    }

    const encodedData = encodeAbiParameters(
      [
        { type: "uint8" },
        { type: "uint256" },
      ],
      [0, maxWithdrawValue],
    );

    return executeVaultTransaction(
      "Execute strategy",
      "Confirm the guardian strategy execution in your wallet.",
      async () =>
        executeWrite({
          abi: vaultAbi,
          address: resolvedVaultAddress,
          functionName: "executeStrategy",
          args: [aaveAdapterAddress, encodedData],
          options: { waitForReceipt: true },
        }),
    );
  };

  const isVaultGuardian = useMemo(
    () =>
      Boolean(
        connection.address &&
          vaultDetail?.guardian &&
          connection.address.toLowerCase() === vaultDetail.guardian.toLowerCase(),
      ),
    [connection.address, vaultDetail?.guardian],
  );

  const canShowGuardianOperations =
    capabilities.canAccessGuardianOperations && isVaultGuardian;

  const vault: VaultDetailData = {
    address: resolvedVaultAddress ?? vaultAddress ?? "—",
    asset: assetSymbol,
    guardian: vaultDetail?.guardian ?? "—",
    status: vaultDetail?.active ? "Active" : "Inactive",
    registeredAt:
      vaultDetail?.registeredAt != null
        ? parseTimestamp(Number(vaultDetail.registeredAt))
            .toISOString()
            .slice(0, 10)
        : "—",
    decimals: vaultDecimals,
    totalAssets: formatTokenAmount(
      totalAssetsValue,
      assetSymbol === "—" ? undefined : assetSymbol,
      assetDecimals,
    ),
  };

  const position: VaultDetailPosition = {
    depositedAssets: formatTokenAmount(
      depositedAssetsValue,
      assetSymbol === "—" ? undefined : assetSymbol,
      assetDecimals,
    ),
    mintedShares: formatTokenAmount(mintedSharesValue, undefined, vaultDecimals),
    withdrawableAssets: formatTokenAmount(
      maxWithdrawValue,
      assetSymbol === "—" ? undefined : assetSymbol,
      assetDecimals,
    ),
    redeemableShares: formatTokenAmount(maxRedeemValue, undefined, vaultDecimals),
  };

  const controls: VaultDetailControls = {
    depositsEnabled: !isVaultDepositsPaused && vaultDetail?.active === true,
    strategyExecutionEnabled: !isExecutionPaused && vaultDetail?.active === true,
  };

  return {
    vault,
    position,
    controls,
    capabilities,
    isSubmitting,
    depositAssetBalance,
    hasDepositAssetBalance,
    isVaultGuardian,
    canShowGuardianOperations,
    deposit,
    mint,
    withdraw,
    redeem,
    executeStrategy,
  };
}
