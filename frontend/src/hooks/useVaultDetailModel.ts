import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type VaultDetailStatus = "Active" | "Inactive";

export type VaultDetailData = {
  address: string;
  asset: string;
  guardian: string;
  status: VaultDetailStatus;
  registeredAt: string;
  decimals: number;
};

export type VaultPosition = {
  depositedAssets: string;
  mintedShares: string;
  withdrawableAssets: string;
  redeemableShares: string;
};

export type VaultControls = {
  depositsEnabled: boolean;
  strategyExecutionEnabled: boolean;
};

export type VaultDetailModel = {
  vault: VaultDetailData;
  position: VaultPosition;
  controls: VaultControls;
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useVaultDetailModel(vaultAddress?: string): VaultDetailModel {
  const capabilities = useProtocolCapabilities();

  const vault: VaultDetailData = {
    address: vaultAddress ?? "0x91A2...5d19",
    asset: "USDC",
    guardian: "0xA13F...91c2",
    status: "Active",
    registeredAt: "2026-01-12",
    decimals: 6,
  };

  const position: VaultPosition = {
    depositedAssets: "12,500.00",
    mintedShares: "12,500.00",
    withdrawableAssets: "12,100.00",
    redeemableShares: "12,500.00",
  };

  const controls: VaultControls = {
    depositsEnabled: true,
    strategyExecutionEnabled: true,
  };

  // TODO:
  // vault.address -> route param /vaults/:vaultAddress
  // vault.asset / guardian / registeredAt / status -> VaultRegistry.getVaultDetail(vaultAddress)
  // vault.status real -> VaultRegistry.isActiveVault(vaultAddress)
  // vault.decimals -> VaultImplementation.decimals()
  //
  // position.depositedAssets -> balance del usuario en asset subyacente depositado
  // position.mintedShares -> shares del usuario
  // position.withdrawableAssets -> previewWithdraw / lógica equivalente si decides exponerla
  // position.redeemableShares -> previewRedeem / lógica equivalente si decides exponerla
  //
  // controls.depositsEnabled ->
  //   !ProtocolCore.isDepositsPaused() && vault.status === "Active"
  //
  // controls.strategyExecutionEnabled ->
  //   !RiskManager.executionPaused && capabilities.canExecuteStrategy
  //
  // writes que se conectarán desde la vista:
  // - VaultImplementation.deposit(...)
  // - VaultImplementation.mint(...)
  // - VaultImplementation.withdraw(...)
  // - VaultImplementation.redeem(...)
  // - VaultImplementation.executeStrategy(...)

  return {
    vault,
    position,
    controls,
    capabilities,
  };
}