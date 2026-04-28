import { getVaultRegistryContract } from "@dao/contracts-sdk";
import { useEffect, useMemo, useState } from "react";
import type {
  VaultItem,
  VaultsFilters,
  VaultsFilterStatus,
  VaultsMetrics,
  VaultsModel,
} from "@/types/models/vaults";
import { useProtocolCapabilities } from "./useProtocolCapabilities";
import { useChainId, useReadContracts } from "wagmi";
import { useVaultsModelProtocolReadDefinitions } from "./definitions/protocolReads";
import { useProtocolReads } from "./useProtocolReads";
import { getVaultFactoryContract } from "./getVaultFactoryContract";
import { abiERC20, formatAddress, parseTimestamp } from "@/utils";
import type { Address } from "viem";
import { getReadContractResult, ZERO_ADDRESS } from "./shared/contractResults";
import type { VaultRegistryDetail } from "./shared/contractTypes";
import { resolveOptionalContract } from "./shared/resolveContract";

export function useVaultsModel(): VaultsModel {
  const chainId = useChainId();
  const capabilities = useProtocolCapabilities();
  const {
    vaultCount,
    totalGuardians,
    isDepositsActiveVaults,
    isCreationActiveVaults,
    listVaults,
  } = useProtocolReads(
    useVaultsModelProtocolReadDefinitions,
  );

  const vaultRegistryConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getVaultRegistryContract);
  }, [chainId]);

  const vaultFactoryConfig = useMemo(() => {
    return resolveOptionalContract(chainId, getVaultFactoryContract);
  }, [chainId]);

  const vaultAddresses = useMemo(
    () => ((listVaults as readonly Address[] | undefined) ?? []),
    [listVaults],
  );

  const { data: vaultDetailsData } = useReadContracts({
    allowFailure: true,
    contracts: vaultRegistryConfig
      ? vaultAddresses.map((vaultAddress) => ({
          abi: vaultRegistryConfig.abi,
          address: vaultRegistryConfig.address,
          functionName: "getVaultDetail" as const,
          args: [vaultAddress],
        }))
      : [],
    query: {
      enabled: Boolean(vaultRegistryConfig) && vaultAddresses.length > 0,
    },
  });

  const vaultDetails = useMemo(
    () =>
      (vaultDetailsData ?? []).map((item) =>
        getReadContractResult<VaultRegistryDetail>(item),
      ),
    [vaultDetailsData],
  );

  const vaultDetailsWithAsset = useMemo(
    () =>
      vaultDetails.reduce<Array<{ index: number; detail: VaultRegistryDetail }>>(
        (accumulator, detail, index) => {
          if (!detail?.asset) {
            return accumulator;
          }

          accumulator.push({
            index,
            detail,
          });

          return accumulator;
        },
        [],
      ),
    [vaultDetails],
  );

  const { data: assetSymbolsData } = useReadContracts({
    allowFailure: true,
    contracts: vaultDetailsWithAsset.map(({ detail }) => ({
        abi: abiERC20,
        address: detail.asset,
        functionName: "symbol" as const,
      })),
    query: {
      enabled: vaultDetailsWithAsset.length > 0,
    },
  });

  const assetSymbolsByVaultIndex = useMemo(() => {
    return vaultDetailsWithAsset.reduce<Record<number, string>>(
      (accumulator, { index, detail }, assetIndex) => {
        accumulator[index] =
          getReadContractResult<string>(assetSymbolsData?.[assetIndex]) ??
          formatAddress(detail.asset);

        return accumulator;
      },
      {},
    );
  }, [assetSymbolsData, vaultDetailsWithAsset]);

  const { data: vaultFactoryWiringData } = useReadContracts({
    allowFailure: true,
    contracts: vaultFactoryConfig
      ? [
          {
            abi: vaultFactoryConfig.abi,
            address: vaultFactoryConfig.address,
            functionName: "router" as const,
          },
          {
            abi: vaultFactoryConfig.abi,
            address: vaultFactoryConfig.address,
            functionName: "core" as const,
          },
          {
            abi: vaultFactoryConfig.abi,
            address: vaultFactoryConfig.address,
            functionName: "guardianAdministrator" as const,
          },
          {
            abi: vaultFactoryConfig.abi,
            address: vaultFactoryConfig.address,
            functionName: "vaultRegistry" as const,
          },
        ]
      : [],
    query: {
      enabled: Boolean(vaultFactoryConfig),
    },
  });

  const vaultFactoryWiring = useMemo(() => {
    return [
      getReadContractResult<string>(vaultFactoryWiringData?.[0]) ?? ZERO_ADDRESS,
      getReadContractResult<string>(vaultFactoryWiringData?.[1]) ?? ZERO_ADDRESS,
      getReadContractResult<string>(vaultFactoryWiringData?.[2]) ?? ZERO_ADDRESS,
      getReadContractResult<string>(vaultFactoryWiringData?.[3]) ?? ZERO_ADDRESS,
    ];
  }, [vaultFactoryWiringData]);

  const vaultFactoryConfiguredWiringCount = vaultFactoryWiring.filter(
    (value) => value !== ZERO_ADDRESS,
  ).length;

  const vaults: VaultItem[] = useMemo(() => {
    return vaultAddresses.reduce<VaultItem[]>((accumulator, vaultAddress, index) => {
      const detail = vaultDetails[index];

      if (!detail) {
        return accumulator;
      }

      accumulator.push({
        address: formatAddress(vaultAddress),
        fullAddress: vaultAddress,
        asset: assetSymbolsByVaultIndex[index] ?? formatAddress(detail.asset),
        guardian: formatAddress(detail.guardian),
        status: detail.active ? "Active" : "Inactive",
        registeredAt: detail.registeredAt
          ? parseTimestamp(Number(detail.registeredAt)).toISOString().slice(0, 10)
          : "—",
      });

      return accumulator;
    }, []);
  }, [assetSymbolsByVaultIndex, vaultAddresses, vaultDetails]);

  const totalVaultsValue =
    typeof vaultCount === "bigint" ? Number(vaultCount) : vaults.length;

  const [filters, setFilters] = useState<VaultsFilters>({
    asset: "All Assets",
    guardian: "",
    status: "All",
  });

  const availableAssets = useMemo(() => {
    return Array.from(new Set(vaults.map((vault) => vault.asset))).sort();
  }, [vaults]);

  const availableGuardians = useMemo(() => {
    return Array.from(new Set(vaults.map((vault) => vault.guardian))).sort();
  }, [vaults]);

  useEffect(() => {
    if (
      filters.asset !== "All Assets" &&
      !availableAssets.includes(filters.asset)
    ) {
      setFilters((prev) => ({
        ...prev,
        asset: "All Assets",
      }));
    }
  }, [availableAssets, filters.asset]);

  const setAssetFilter = (asset: string) => {
    setFilters((prev) => ({
      ...prev,
      asset,
    }));
  };

  const setGuardianFilter = (guardian: string) => {
    setFilters((prev) => ({
      ...prev,
      guardian,
    }));
  };

  const setStatusFilter = (status: VaultsFilterStatus) => {
    setFilters((prev) => ({
      ...prev,
      status,
    }));
  };

  const filteredVaults = useMemo(() => {
    return vaults.filter((vault) => {
      const matchesAsset =
        filters.asset === "All Assets" || vault.asset === filters.asset;

      const matchesGuardian =
        filters.guardian.trim() === "" ||
        vault.guardian.toLowerCase().includes(filters.guardian.toLowerCase());

      const matchesStatus =
        filters.status === "All" || vault.status === filters.status;

      return matchesAsset && matchesGuardian && matchesStatus;
    });
  }, [vaults, filters]);

  const metrics: VaultsMetrics = useMemo(() => {
    return {
      totalVaults: totalVaultsValue,
      activeVaults: vaults.filter((v) => v.status === "Active").length,
      assetsCovered: new Set(vaults.map((v) => v.asset)).size,
      guardianCoverage:
        typeof totalGuardians === "bigint"
          ? Number(totalGuardians)
          : new Set(vaults.map((v) => v.guardian)).size,
    };
  }, [totalGuardians, totalVaultsValue, vaults]);

  const isVaultDepositsPaused = isDepositsActiveVaults === true;
  const isVaultCreationPaused = isCreationActiveVaults === true;
  const hasVaultRegistry = Boolean(vaultRegistryConfig);
  const vaultExplorerStatus = hasVaultRegistry
    ? totalVaultsValue > 0
      ? "Live"
      : "Empty"
    : "Unavailable";
  const vaultExplorerSubtitle = hasVaultRegistry
    ? totalVaultsValue > 0
      ? `${totalVaultsValue} registered vault${totalVaultsValue === 1 ? "" : "s"} found.`
      : "VaultRegistry is deployed, but no registered vaults were returned."
    : "VaultRegistry is not deployed on the connected network.";
  const guardianRoutingStatus =
    vaultFactoryConfiguredWiringCount === 4
      ? "Linked"
      : vaultFactoryConfiguredWiringCount > 0
        ? "Partial"
        : "Unconfigured";
  const guardianRoutingSubtitle =
    vaultFactoryConfiguredWiringCount === 4
      ? "VaultFactory router, core, guardian administrator and registry are wired."
      : vaultFactoryConfiguredWiringCount > 0
        ? `${vaultFactoryConfiguredWiringCount}/4 VaultFactory wiring points are configured.`
        : "VaultFactory wiring is not configured on this network.";
  const registryVisibilityStatus = hasVaultRegistry
    ? totalVaultsValue > 0
      ? "Tracked"
      : "Empty"
    : "Unavailable";
  const registryVisibilitySubtitle = hasVaultRegistry
    ? totalVaultsValue > 0
      ? `VaultRegistry detail data is available for ${totalVaultsValue} registered vaults.`
      : "VaultRegistry detail data is available, but no vaults are registered yet."
    : "VaultRegistry is not deployed on the connected network.";

  /*
    totalVaults: vaultCount;
    activeVaults: hay que llamar a cada vault para saber si está activa o no, así que lo derivamos de vaults filtrando por status
    guardianCoverage: totalGuardians

    Deposit Access: isDepositsActiveVaults
  */
  //
  // TODO:
  // vaults -> VaultRegistry.getAllVaults()
  // por cada vault -> VaultRegistry.getVaultDetail(vault)
  // status real -> VaultRegistry.isActiveVault(vault)
  //
  // filtros:
  // - asset -> derivados de assets disponibles
  // - guardian -> búsqueda real por guardian
  // - status -> activo / inactivo
  //
  // metrics.totalVaults -> VaultRegistry.totalVaults()
  // metrics.activeVaults -> derivado de isActiveVault
  // metrics.assetsCovered -> assets únicos derivados del registry
  // metrics.guardianCoverage -> guardianes únicos derivados del registry
  //
  // si luego quieres integrar Graph:
  // este hook es buen candidato para mover explorer/search/filter a indexación

  return {
    vaults,
    filteredVaults,
    availableAssets,
    availableGuardians,
    isVaultDepositsPaused,
    isVaultCreationPaused,
    vaultExplorerStatus,
    vaultExplorerSubtitle,
    guardianRoutingStatus,
    guardianRoutingSubtitle,
    registryVisibilityStatus,
    registryVisibilitySubtitle,
    filters,
    metrics,
    capabilities,
    setAssetFilter,
    setGuardianFilter,
    setStatusFilter,
  };
}
