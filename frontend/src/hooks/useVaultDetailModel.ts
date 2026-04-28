import { addresses } from "@dao/contracts-sdk";
import { useEffect, useMemo, useState } from "react";
import { useChainId, useConnection } from "wagmi";
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

import type { VaultRegistryDetail } from "./shared/contractTypes";
import useWriteContracts from "./useWriteContracts";
import { useProtocolReads } from "./useProtocolReads";
import type { ProtocolReadDefinition } from "./useProtocolReads";
import useProtocolReadExecutor from "./useProtocolReadExecutor";
import { resolveProtocolContract } from "./protocolContracts";

type VaultDetailProtocolContext = {
  vaultAddress: Address | undefined;
};

const vaultDetailProtocolDefinitions: ProtocolReadDefinition<
  "vaultDetail" | "isVaultDepositsPaused" | "isExecutionPaused",
  VaultDetailProtocolContext
>[] = [
  {
    key: "vaultDetail",
    contract: "getVaultRegistryContract",
    functionName: "getVaultDetail",
    args: (context) =>
      context.vaultAddress ? [context.vaultAddress] : undefined,
  },
  {
    key: "isVaultDepositsPaused",
    contract: "getProtocolCoreContract",
    functionName: "isVaultDepositsPaused",
  },
  {
    key: "isExecutionPaused",
    contract: "getRiskManagerContract",
    functionName: "executionPaused",
  },
];

export function useVaultDetailModel(vaultAddress?: string): VaultDetailModel {
  const chainId = useChainId();
  const capabilities = useProtocolCapabilities();
  const connection = useConnection();
  const { executeRead } = useProtocolReadExecutor();
  const { executeWrite } = useWriteContracts();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const [vaultDecimalsValue, setVaultDecimals] = useState<number | undefined>();
  const [mintedShares, setMintedShares] = useState<bigint | undefined>();
  const [maxWithdraw, setMaxWithdraw] = useState<bigint | undefined>();
  const [maxRedeem, setMaxRedeem] = useState<bigint | undefined>();
  const [totalAssets, setTotalAssets] = useState<bigint | undefined>();
  const [depositedAssets, setDepositedAssets] = useState<bigint | undefined>();
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  const resolvedVaultAddress = useMemo(
    () =>
      vaultAddress && isValidAddress(vaultAddress)
        ? (vaultAddress as Address)
        : undefined,
    [vaultAddress],
  );

  const vaultDetailProtocolContext: VaultDetailProtocolContext = {
    vaultAddress: resolvedVaultAddress,
  };

  const {
    vaultDetail,
    isVaultDepositsPaused,
    isExecutionPaused,
    refetch: refetchProtocol,
  } = useProtocolReads(
    vaultDetailProtocolDefinitions,
    vaultDetailProtocolContext,
  );

  const vaultDetailTyped = vaultDetail as VaultRegistryDetail | undefined;
  const isVaultDepositsPausedTyped =
    (isVaultDepositsPaused as boolean) ?? false;
  const isExecutionPausedTyped = (isExecutionPaused as boolean) ?? false;

  const assetDefinitions: ProtocolReadDefinition<'assetSymbol' | 'assetDecimals' | 'assetBalance'>[] = vaultDetailTyped?.asset ? [
    {
      key: 'assetSymbol',
      contract: { abi: abiERC20, address: vaultDetailTyped.asset },
      functionName: 'symbol',
    },
    {
      key: 'assetDecimals',
      contract: { abi: abiERC20, address: vaultDetailTyped.asset },
      functionName: 'decimals',
    },
    {
      key: 'assetBalance',
      contract: { abi: abiERC20, address: vaultDetailTyped.asset },
      functionName: 'balanceOf',
      args: connection.address ? [connection.address] : undefined,
    },
  ] : [];

  const assetReads = useProtocolReads(assetDefinitions);

  // Fetch vault data using executeRead
  useEffect(() => {
    if (!resolvedVaultAddress || !connection.address) return;

    const fetchVaultData = async () => {
      try {
        const decimals = await executeRead({
          functionName: "decimals",
          functionContract: "getVaultImplementationContract",
          args: [],
        });
        setVaultDecimals(decimals as number);

        const shares = await executeRead({
          functionName: "balanceOf",
          functionContract: "getVaultImplementationContract",
          args: [connection.address],
        });
        setMintedShares(shares as bigint);

        const maxW = await executeRead({
          functionName: "maxWithdraw",
          functionContract: "getVaultImplementationContract",
          args: [connection.address],
        });
        setMaxWithdraw(maxW as bigint);

        const maxR = await executeRead({
          functionName: "maxRedeem",
          functionContract: "getVaultImplementationContract",
          args: [connection.address],
        });
        setMaxRedeem(maxR as bigint);

        const totalA = await executeRead({
          functionName: "totalAssets",
          functionContract: "getVaultImplementationContract",
          args: [],
        });
        setTotalAssets(totalA as bigint);
      } catch (error) {
        console.error("Error fetching vault data:", error);
      }
    };

    fetchVaultData();
  }, [resolvedVaultAddress, connection.address, executeRead, refreshTrigger]);

  // Fetch preview data
  useEffect(() => {
    if (!resolvedVaultAddress || !mintedShares || mintedShares <= 0n) return;

    const fetchPreviewData = async () => {
      try {
        const deposited = await executeRead({
          functionName: "previewRedeem",
          functionContract: "getVaultImplementationContract",
          args: [mintedShares],
        });
        setDepositedAssets(deposited as bigint);
      } catch (error) {
        console.error("Error fetching preview data:", error);
      }
    };

    fetchPreviewData();
  }, [resolvedVaultAddress, mintedShares, executeRead, refreshTrigger]);

  const mintedSharesValueTyped = mintedShares ?? 0n;

  // Extract values
  const assetSymbolTyped = assetReads.assetSymbol as string | undefined;
  const assetDecimalsTyped = assetReads.assetDecimals as number | undefined ?? 18;
  const assetBalanceTyped = assetReads.assetBalance as bigint | undefined ?? 0n;
  const vaultDecimalsTyped = vaultDecimalsValue ?? assetDecimalsTyped;
  const maxWithdrawValueTyped = maxWithdraw ?? 0n;
  const maxRedeemValueTyped = maxRedeem ?? 0n;
  const totalAssetsValueTyped = totalAssets ?? 0n;
  const depositedAssetsValueTyped = depositedAssets ?? 0n;

  // Assign to old variable names for compatibility
  const assetSymbol = assetSymbolTyped ?? (vaultDetailTyped?.asset ? formatAddress(vaultDetailTyped.asset) : "—");
  const assetDecimals = assetDecimalsTyped;
  const depositAssetBalanceValue = assetBalanceTyped;
  const depositAssetBalance = formatTokenAmount(
    depositAssetBalanceValue,
    assetSymbol === "—" ? undefined : assetSymbol,
    assetDecimals,
  );
  const hasDepositAssetBalance = depositAssetBalanceValue > 0n;
  const vaultDecimals = vaultDecimalsTyped;
  const mintedSharesValue = mintedSharesValueTyped;
  const maxWithdrawValue = maxWithdrawValueTyped;
  const maxRedeemValue = maxRedeemValueTyped;
  const totalAssetsValue = totalAssetsValueTyped;
  const depositedAssetsValue = depositedAssetsValueTyped;







  const aaveAdapterAddress = useMemo(
    () =>
      chainId
        ? addresses[chainId as keyof typeof addresses]?.aaveV3Adapter
        : undefined,
    [chainId],
  );

  const refreshVaultData = async () => {
    await Promise.allSettled([
      refetchProtocol?.(),
      assetReads.refetch?.(),
      setRefreshTrigger(prev => prev + 1),
    ]);
  };

  const approveAssetForVault = async (amount: bigint) => {
    if (!vaultDetailTyped?.asset || !resolvedVaultAddress) return;

    return executeWrite({
      abi: abiERC20,
      address: vaultDetailTyped.asset,
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
    if (
      !resolvedVaultAddress ||
      !connection.address ||
      !vaultDetailTyped?.asset
    )
      return false;

    const parsedAmount = parseTokenAmount(amount, assetDecimals);
    if (parsedAmount <= 0n) return false;

    return executeVaultTransaction(
      "Deposit assets",
      "Confirm the deposit transaction in your wallet.",
      async () => {
        const approval = await approveAssetForVault(parsedAmount);

        if (
          !approval ||
          !("receipt" in approval) ||
          approval.receipt?.status !== "success"
        ) {
          throw new Error("Token approval failed.");
        }

        const contract = resolveProtocolContract(chainId, "getVaultImplementationContract");
        if (!contract) throw new Error("Vault implementation contract not found");

        return executeWrite({
          abi: contract.abi,
          address: resolvedVaultAddress,
          functionName: "deposit",
          args: [parsedAmount, connection.address as Address],
          options: { waitForReceipt: true },
        });
      },
    );
  };

  const mint = async (amount: string): Promise<boolean> => {
    if (
      !resolvedVaultAddress ||
      !connection.address ||
      !vaultDetailTyped?.asset
    )
      return false;

    const parsedShares = parseTokenAmount(amount, vaultDecimals);
    if (parsedShares <= 0n) return false;

    return executeVaultTransaction(
      "Mint shares",
      "Confirm the mint transaction in your wallet.",
      async () => {
        const approval = await approveAssetForVault(parsedShares);

        if (
          !approval ||
          !("receipt" in approval) ||
          approval.receipt?.status !== "success"
        ) {
          throw new Error("Token approval failed.");
        }

        const contract = resolveProtocolContract(chainId, "getVaultImplementationContract");
        if (!contract) throw new Error("Vault implementation contract not found");

        return executeWrite({
          abi: contract.abi,
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
      async () => {
        const contract = resolveProtocolContract(chainId, "getVaultImplementationContract");
        if (!contract) throw new Error("Vault implementation contract not found");

        return executeWrite({
          abi: contract.abi,
          address: resolvedVaultAddress,
          functionName: "withdraw",
          args: [
            parsedAmount,
            connection.address as Address,
            connection.address as Address,
          ],
          options: { waitForReceipt: true },
        });
      },
    );
  };

  const redeem = async (amount: string): Promise<boolean> => {
    if (!resolvedVaultAddress || !connection.address) return false;

    const parsedShares = parseTokenAmount(amount, vaultDecimals);
    if (parsedShares <= 0n) return false;

    return executeVaultTransaction(
      "Redeem shares",
      "Confirm the redeem transaction in your wallet.",
      async () => {
        const contract = resolveProtocolContract(chainId, "getVaultImplementationContract");
        if (!contract) throw new Error("Vault implementation contract not found");

        return executeWrite({
          abi: contract.abi,
          address: resolvedVaultAddress,
          functionName: "redeem",
          args: [
            parsedShares,
            connection.address as Address,
            connection.address as Address,
          ],
          options: { waitForReceipt: true },
        });
      },
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
      [{ type: "uint8" }, { type: "uint256" }],
      [0, maxWithdrawValue],
    );

    return executeVaultTransaction(
      "Execute strategy",
      "Confirm the guardian strategy execution in your wallet.",
      async () => {
        const contract = resolveProtocolContract(chainId, "getVaultImplementationContract");
        if (!contract) throw new Error("Vault implementation contract not found");

        return executeWrite({
          abi: contract.abi,
          address: resolvedVaultAddress,
          functionName: "executeStrategy",
          args: [aaveAdapterAddress, encodedData],
          options: { waitForReceipt: true },
        });
      },
    );
  };

  const isVaultGuardian = useMemo(
    () =>
      Boolean(
        connection.address &&
        vaultDetailTyped?.guardian &&
        connection.address.toLowerCase() ===
          vaultDetailTyped.guardian.toLowerCase(),
      ),
    [connection.address, vaultDetailTyped?.guardian],
  );

  const canShowGuardianOperations =
    capabilities.canAccessGuardianOperations && isVaultGuardian;

  const vault: VaultDetailData = {
    address: resolvedVaultAddress ?? vaultAddress ?? "—",
    asset: assetSymbol,
    guardian: vaultDetailTyped?.guardian ?? "—",
    status: vaultDetailTyped?.active ? "Active" : "Inactive",
    registeredAt:
      vaultDetailTyped?.registeredAt != null
        ? parseTimestamp(Number(vaultDetailTyped.registeredAt))
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
    mintedShares: formatTokenAmount(
      mintedSharesValue,
      undefined,
      vaultDecimals,
    ),
    withdrawableAssets: formatTokenAmount(
      maxWithdrawValue,
      assetSymbol === "—" ? undefined : assetSymbol,
      assetDecimals,
    ),
    redeemableShares: formatTokenAmount(
      maxRedeemValue,
      undefined,
      vaultDecimals,
    ),
  };

  const controls: VaultDetailControls = {
    depositsEnabled:
      !isVaultDepositsPausedTyped && vaultDetailTyped?.active === true,
    strategyExecutionEnabled:
      !isExecutionPausedTyped && vaultDetailTyped?.active === true,
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