import { useState } from "react";
import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type TreasuryOperationToken = {
  symbol: string;
  address: string;
  category: "DAO Asset" | "Non-DAO Asset";
};

export type TreasuryOperationsModel = {
  tokens: TreasuryOperationToken[];
  selectedToken: TreasuryOperationToken | null;
  setSelectedToken: (token: TreasuryOperationToken) => void;

  amount: string;
  setAmount: (value: string) => void;

  recipient: string;
  setRecipient: (value: string) => void;

  canExecute: boolean;
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useTreasuryOperationsModel(): TreasuryOperationsModel {
  const capabilities = useProtocolCapabilities();

  const tokens: TreasuryOperationToken[] = [
    { symbol: "USDC", address: "0xUSDC", category: "DAO Asset" },
    { symbol: "DAI", address: "0xDAI", category: "DAO Asset" },
    { symbol: "LINK", address: "0xLINK", category: "Non-DAO Asset" },
  ];

  const [selectedToken, setSelectedToken] = useState<TreasuryOperationToken | null>(
    tokens[0]
  );
  const [amount, setAmount] = useState("");
  const [recipient, setRecipient] = useState("");

  const canExecute =
    capabilities.canOpenTreasuryOperations &&
    !!selectedToken &&
    amount.trim() !== "" &&
    recipient.trim() !== "";

  // TODO:
  // tokens -> lista soportada/configurada por red
  // selectedToken.category -> ProtocolCore.hasGenesisToken(token)
  //
  // operaciones reales según categoría:
  // DAO Asset -> Treasury.withdrawDaoERC20(...)
  // Non-DAO Asset -> Treasury.withdrawNotAssetDaoERC20(...)
  // Native -> Treasury.withdrawDaoNative(...)
  //
  // validaciones reales:
  // - address válida
  // - amount > 0
  // - balances disponibles
  //
  // separar luego por tipo de operación:
  // - DAO Asset Withdrawal
  // - Non-DAO Asset Withdrawal
  // - Native Treasury Withdrawal

  return {
    tokens,
    selectedToken,
    setSelectedToken,
    amount,
    setAmount,
    recipient,
    setRecipient,
    canExecute,
    capabilities,
  };
}