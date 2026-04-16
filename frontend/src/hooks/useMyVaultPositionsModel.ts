import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type VaultPositionItem = {
  vaultAddress: string;
  asset: string;
  deposited: string;
  shares: string;
  value: string;
};

export type MyVaultPositionsModel = {
  positions: VaultPositionItem[];
  totalDepositedValue: string;
  totalShareExposure: string;
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useMyVaultPositionsModel(): MyVaultPositionsModel {
  const capabilities = useProtocolCapabilities();

  const positions: VaultPositionItem[] = [
    {
      vaultAddress: "0x91A2...5d19",
      asset: "USDC",
      deposited: "12,500.00",
      shares: "12,500.00",
      value: "$12,500.00",
    },
    {
      vaultAddress: "0x72B4...1f08",
      asset: "DAI",
      deposited: "5,200.00",
      shares: "5,200.00",
      value: "$5,200.00",
    },
  ];

  const totalDepositedValue = "$17,700.00";
  const totalShareExposure = "17,700.00";

  // TODO:
  // positions -> leer posiciones del usuario por vault
  // value -> pricing layer / subgraph / backend auxiliar
  // totalDepositedValue -> agregación de posiciones
  // totalShareExposure -> suma de shares o equivalente formateado
  //
  // idealmente:
  // - usar indexación para historial
  // - enlazar con VaultDetail por vaultAddress

  return {
    positions,
    totalDepositedValue,
    totalShareExposure,
    capabilities,
  };
}