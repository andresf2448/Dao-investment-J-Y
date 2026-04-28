import { useMemo } from "react";
import { useConnection, useReadContracts } from "wagmi";
import type { Address } from "viem";
import type {
  MyVaultPositionsModel,
  VaultPositionItem,
} from "@/types/models/myVaultPositions";
import { useProtocolCapabilities } from "./useProtocolCapabilities";
import { useProtocolReads } from "./useProtocolReads";
import { useVaultsModelProtocolReadDefinitions } from "./definitions/protocolReads";
import { getVaultRegistryContract } from "@dao/contracts-sdk";
import { useChainId } from "wagmi";
import { resolveOptionalContract } from "./shared/resolveContract";
import { getReadContractResult } from "./shared/contractResults";
import type { VaultRegistryDetail } from "./shared/contractTypes";
import { formatTokenAmount, formatAddress } from "@/utils";
import { abiERC20 } from "@/utils";

export function useMyVaultPositionsModel(): MyVaultPositionsModel {
  const chainId = useChainId();
  const connection = useConnection();
  const capabilities = useProtocolCapabilities();

  const vaultRegistryConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getVaultRegistryContract);
  }, [chainId]);

  // Get all registered vaults and filter by connected account investment
  const { data: allVaultsData } = useReadContracts({
    allowFailure: true,
    contracts: vaultRegistryConfig
      ? [
          {
            abi: vaultRegistryConfig.abi,
            address: vaultRegistryConfig.address,
            functionName: "getAllVaults",
          },
        ]
      : [],
    query: {
      enabled: Boolean(vaultRegistryConfig),
    },
  });

  const vaultAddresses = useMemo(
    () => getReadContractResult<Address[]>(allVaultsData?.[0]) ?? [],
    [allVaultsData],
  );

  // Read balanceOf for each vault for the connected user
  const { data: balanceData } = useReadContracts({
    allowFailure: true,
    contracts:
      vaultRegistryConfig && connection.address
        ? vaultAddresses.map((vaultAddress) => ({
            abi: [
              {
                type: "function",
                name: "balanceOf",
                stateMutability: "view",
                inputs: [{ name: "account", type: "address" }],
                outputs: [{ name: "", type: "uint256" }],
              },
            ],
            address: vaultAddress,
            functionName: "balanceOf",
            args: [connection.address as Address],
          }))
        : [],
    query: {
      enabled: Boolean(vaultRegistryConfig && connection.address && vaultAddresses.length > 0),
    },
  });
  // Read vault details for all vaults
  const { data: vaultDetailsData } = useReadContracts({
    allowFailure: true,
    contracts: vaultRegistryConfig
      ? vaultAddresses.map((vaultAddress) => ({
          abi: vaultRegistryConfig.abi,
          address: vaultRegistryConfig.address,
          functionName: "getVaultDetail",
          args: [vaultAddress],
        }))
      : [],
    query: {
      enabled: Boolean(vaultRegistryConfig && vaultAddresses.length > 0),
    },
  });

  const vaultDetails = useMemo(
    () =>
      (vaultDetailsData ?? []).map((item) =>
        getReadContractResult<VaultRegistryDetail>(item),
      ),
    [vaultDetailsData],
  );

  // Read asset symbols
  const vaultDetailsWithAsset = useMemo(
    () =>
      vaultDetails.reduce<Array<{ index: number; asset: Address }>>(
        (accumulator, detail, index) => {
          if (detail?.asset) {
            accumulator.push({
              index,
              asset: detail.asset,
            });
          }
          return accumulator;
        },
        [],
      ),
    [vaultDetails],
  );

  const { data: assetSymbolsData } = useReadContracts({
    allowFailure: true,
    contracts: vaultDetailsWithAsset.map(({ asset }) => ({
      abi: abiERC20,
      address: asset,
      functionName: "symbol",
    })),
    query: {
      enabled: vaultDetailsWithAsset.length > 0,
    },
  });

  const assetSymbolsByIndex = useMemo(() => {
    return vaultDetailsWithAsset.reduce<Record<number, string>>(
      (accumulator, { index, asset }, assetIndex) => {
        accumulator[index] =
          getReadContractResult<string>(assetSymbolsData?.[assetIndex]) ??
          formatAddress(asset);
        return accumulator;
      },
      {},
    );
  }, [assetSymbolsData, vaultDetailsWithAsset]);

  const vaultsWithBalance = useMemo(() => {
    return vaultAddresses
      .map((vaultAddress, index) => ({
        vaultAddress,
        index,
        balance: getReadContractResult<bigint>(balanceData?.[index]) ?? 0n,
        detail: vaultDetails[index],
      }))
      .filter(({ balance }) => balance > 0n);
  }, [vaultAddresses, balanceData, vaultDetails]);

  // Read previewRedeem for deposited
  const { data: previewRedeemData } = useReadContracts({
    allowFailure: true,
    contracts: vaultsWithBalance.map(({ vaultAddress, balance }) => ({
      abi: [
        {
          type: "function",
          name: "previewRedeem",
          stateMutability: "view",
          inputs: [{ name: "shares", type: "uint256" }],
          outputs: [{ name: "", type: "uint256" }],
        },
      ],
      address: vaultAddress,
      functionName: "previewRedeem",
      args: [balance],
    })),
    query: {
      enabled: vaultsWithBalance.length > 0,
    },
  });

  const previewRedeemByVault = useMemo(() => {
    return vaultsWithBalance.reduce<Record<string, bigint>>(
      (accumulator, { vaultAddress }, index) => {
        accumulator[vaultAddress] = getReadContractResult<bigint>(previewRedeemData?.[index]) ?? 0n;
        return accumulator;
      },
      {},
    );
  }, [vaultsWithBalance, previewRedeemData]);

  const positions = useMemo<VaultPositionItem[]>(() => {
    return vaultsWithBalance.map(({ vaultAddress, index, balance, detail }) => {
      const assetSymbol =
        assetSymbolsByIndex[index] ??
        (detail?.asset ? formatAddress(detail.asset) : "—");
      const depositedValue = previewRedeemByVault[vaultAddress] ?? 0n;
      const deposited = formatTokenAmount(
        depositedValue,
        assetSymbol === "—" ? undefined : assetSymbol,
      );
      const shares = formatTokenAmount(balance);
      const value = `$${deposited.replace(/,/g, "").replace(/\..*/, "")}.00`;

      return {
        vaultAddress,
        asset: assetSymbol,
        deposited,
        shares,
        value,
      };
    });
  }, [vaultsWithBalance, assetSymbolsByIndex, previewRedeemByVault]);

  const totalDepositedValue = useMemo(() => {
    const total = positions.reduce((sum, pos) => {
      const num = parseFloat(pos.deposited.replace(/,/g, ""));
      return sum + (isNaN(num) ? 0 : num);
    }, 0);
    return `$${total.toFixed(2)}`;
  }, [positions]);

  const totalShareExposure = useMemo(() => {
    const total = positions.reduce((sum, pos) => {
      const num = parseFloat(pos.shares.replace(/,/g, ""));
      return sum + (isNaN(num) ? 0 : num);
    }, 0);
    return total.toFixed(2);
  }, [positions]);

  return {
    positions,
    totalDepositedValue,
    totalShareExposure,
    capabilities,
  };
}