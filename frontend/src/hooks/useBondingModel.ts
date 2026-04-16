import { useState } from "react";
import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type BondingAsset = {
  symbol: string;
  address: string;
};

export type BondingState = {
  isFinalized: boolean;
  rate: number; // ejemplo: 100 GOV por 1 ETH
  totalDistributed: string;
};

export type BondingPosition = {
  governanceBalance: string;
  estimatedValue: string;
  totalPurchases: number;
};

export type BondingModel = {
  assets: BondingAsset[];
  selectedAsset: BondingAsset | null;
  setSelectedAsset: (asset: BondingAsset) => void;

  amount: string;
  setAmount: (value: string) => void;

  estimatedTokens: string;

  state: BondingState;
  position: BondingPosition;

  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useBondingModel(): BondingModel {
  const capabilities = useProtocolCapabilities();

  // ===== MOCK ASSETS =====
  const assets: BondingAsset[] = [
    { symbol: "ETH", address: "0xETH" },
    { symbol: "USDC", address: "0xUSDC" },
    { symbol: "DAI", address: "0xDAI" },
  ];

  const [selectedAsset, setSelectedAsset] = useState<BondingAsset | null>(
    assets[0]
  );
  const [amount, setAmount] = useState("");

  // ===== MOCK STATE =====
  const state: BondingState = {
    isFinalized: false,
    rate: 100,
    totalDistributed: "1.2M",
  };

  // ===== CALCULO =====
  const estimatedTokens = calculateEstimatedTokens(amount, state.rate);

  // ===== MOCK USER POSITION =====
  const position: BondingPosition = {
    governanceBalance: "0.00",
    estimatedValue: "$0.00",
    totalPurchases: 0,
  };

  // ===== FUTURO =====
  // TODO:
  // assets -> ProtocolCore.getSupportedGenesisTokens()
  // state.isFinalized -> GenesisBonding.isFinalized()
  // state.rate -> GenesisBonding.rate()
  // state.totalDistributed -> GenesisBonding.totalGovernanceTokenPurchased()
  //
  // estimatedTokens -> cálculo real según token decimals
  //
  // position.governanceBalance -> ERC20.balanceOf(user)
  // position.totalPurchases -> eventos Purchased(user)
  //
  // BUY:
  // -> GenesisBonding.buy(token, amount)
//   const {
  //   assets,
  //   selectedAsset,
  //   setSelectedAsset,
  //   amount,
  //   setAmount,
  //   estimatedTokens,
  //   state,
  //   position,
  //   capabilities
//  } = useBondingModel();

  return {
    assets,
    selectedAsset,
    setSelectedAsset,

    amount,
    setAmount,

    estimatedTokens,

    state,
    position,

    capabilities,
  };
}

/* =========================
   Helpers
========================= */

function calculateEstimatedTokens(amount: string, rate: number): string {
  const numericAmount = parseFloat(amount);

  if (isNaN(numericAmount) || numericAmount <= 0) return "0.00";

  const result = numericAmount * rate;

  return result.toFixed(2);
}