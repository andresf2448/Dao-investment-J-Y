import type { ProtocolCapabilities } from "@/types/capabilities";
import type { Address } from "viem";

export type BondingStatus = "Active" | "Finalized";

export interface BondingAsset {
  symbol: string;
  address: Address;
}

export interface BondingState {
  isFinalized: boolean;
  rate: number;
  totalDistributed: string;
  bondingStatus: BondingStatus;
}

export interface BondingPosition {
  governanceBalance: string;
  estimatedValue: string;
}

export interface BondingModel {
  assets: BondingAsset[];
  selectedAsset: BondingAsset | null;
  setSelectedAsset: (asset: BondingAsset) => void;
  amount: string;
  setAmount: (value: string) => void;
  isAmountValid: boolean;
  amountError?: string;
  canBuy: boolean;
  isSubmitting: boolean;
  estimatedTokens: string;
  state: BondingState;
  position: BondingPosition;
  capabilities: ProtocolCapabilities;
  createTransaction: () => Promise<void>;
  hasSweepRole: boolean;
  sweepToken: string;
  setSweepToken: (value: string) => void;
  sweepTokenError?: string;
  canSweep: boolean;
  sweep: () => Promise<void>;
}
