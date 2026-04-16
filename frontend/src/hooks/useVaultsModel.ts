import { useMemo, useState } from "react";
import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type VaultStatus = "Active" | "Inactive";

export type VaultItem = {
  address: string;
  asset: string;
  guardian: string;
  status: VaultStatus;
  registeredAt: string;
};

export type VaultsFilters = {
  asset: string;
  guardian: string;
  status: "All" | VaultStatus;
};

export type VaultsMetrics = {
  totalVaults: number;
  activeVaults: number;
  assetsCovered: number;
  guardianCoverage: number;
};

export type VaultsModel = {
  vaults: VaultItem[];
  filteredVaults: VaultItem[];
  filters: VaultsFilters;
  metrics: VaultsMetrics;
  capabilities: ReturnType<typeof useProtocolCapabilities>;
  setAssetFilter: (asset: string) => void;
  setGuardianFilter: (guardian: string) => void;
  setStatusFilter: (status: "All" | VaultStatus) => void;
};

export function useVaultsModel(): VaultsModel {
  const capabilities = useProtocolCapabilities();

  const vaults: VaultItem[] = [
    {
      address: "0x91A2...5d19",
      asset: "USDC",
      guardian: "0xA13F...91c2",
      status: "Active",
      registeredAt: "2026-01-12",
    },
    {
      address: "0x72B4...1f08",
      asset: "DAI",
      guardian: "0xC82A...77ee",
      status: "Active",
      registeredAt: "2026-01-09",
    },
    {
      address: "0x18C7...3b41",
      asset: "ETH",
      guardian: "0xF1E1...221c",
      status: "Inactive",
      registeredAt: "2025-12-28",
    },
  ];

  const [filters, setFilters] = useState<VaultsFilters>({
    asset: "All Assets",
    guardian: "",
    status: "All",
  });

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

  const setStatusFilter = (status: "All" | VaultStatus) => {
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
      totalVaults: vaults.length,
      activeVaults: vaults.filter((v) => v.status === "Active").length,
      assetsCovered: new Set(vaults.map((v) => v.asset)).size,
      guardianCoverage: new Set(vaults.map((v) => v.guardian)).size,
    };
  }, [vaults]);

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
    filters,
    metrics,
    capabilities,
    setAssetFilter,
    setGuardianFilter,
    setStatusFilter,
  };
}