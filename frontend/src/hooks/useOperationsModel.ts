import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type OperationsStatus = {
  vaultCreation: "enabled" | "paused";
  vaultDeposits: "enabled" | "paused";
  supportedAssetsCount: number;
  infrastructureState: "linked" | "partial" | "unconfigured";
};

export type InfrastructureWiring = {
  factoryRouter: string;
  factoryCore: string;
  guardianAdministrator: string;
  vaultRegistry: string;
  treasuryProtocolCore: string;
};

export type OperationsModel = {
  status: OperationsStatus;
  wiring: InfrastructureWiring;
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useOperationsModel(): OperationsModel {
  const capabilities = useProtocolCapabilities();

  // ===== MOCK STATUS =====
  const status: OperationsStatus = {
    vaultCreation: "enabled",
    vaultDeposits: "enabled",
    supportedAssetsCount: 6,
    infrastructureState: "linked",
  };

  // ===== MOCK WIRING =====
  const wiring: InfrastructureWiring = {
    factoryRouter: "0xRouter...004",
    factoryCore: "0xCore...001",
    guardianAdministrator: "0xGuard...010",
    vaultRegistry: "0xRegistry...006",
    treasuryProtocolCore: "0xCore...001",
  };

  // ===== FUTURO =====
  // TODO:
  // status.vaultCreation -> ProtocolCore.isVaultCreationPaused()
  // status.vaultDeposits -> ProtocolCore.isDepositsPaused()
  // status.supportedAssetsCount -> contador derivado de activos soportados
  // status.infrastructureState -> derivar según wiring completo/incompleto
  //
  // wiring.factoryRouter -> VaultFactory.router()
  // wiring.factoryCore -> VaultFactory.core()
  // wiring.guardianAdministrator -> VaultFactory.guardianAdministrator()
  // wiring.vaultRegistry -> VaultFactory.vaultRegistry()
  // wiring.treasuryProtocolCore -> Treasury.protocolCore()
  //
  // actions futuras a conectar desde la vista:
  // - ProtocolCore.pauseVaultCreation()
  // - ProtocolCore.unpauseVaultCreation()
  // - ProtocolCore.pauseVaultDeposits()
  // - ProtocolCore.unpauseVaultDeposits()
  // - ProtocolCore.setSupportedVaultAsset(asset, allowed)
  // - ProtocolCore.setSupportedGenesisTokens(address[])
  // - VaultFactory.setRouter(newRouter)
  // - VaultFactory.setCore(newCore)
  // - VaultFactory.setGuardianAdministrator(newGuardianAdministrator)
  // - VaultFactory.setVaultRegistry(newVaultRegistry)
  // - Treasury.setProtocolCore(protocolCore)

  return {
    status,
    wiring,
    capabilities,
  };
}