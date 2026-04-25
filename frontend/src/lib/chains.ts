import { mainnet, sepolia, anvil } from "wagmi/chains";
import { defineChain } from "viem";

export const localAnvil = defineChain({
  id: 31337,
  name: "Anvil",
  nativeCurrency: {
    decimals: 18,
    name: "Ether",
    symbol: "ETH",
  },
  rpcUrls: {
    default: {
      http: ["http://127.0.0.1:8545"],
    },
  },
  blockExplorers: {
    default: {
      name: "Anvil",
      url: "http://127.0.0.1:8545",
    },
  },
});

export const SUPPORTED_CHAINS = [localAnvil, sepolia, mainnet] as const;

export const CHAIN_NAMES: Record<number, string> = {
  [mainnet.id]: "Ethereum",
  [sepolia.id]: "Sepolia",
  [localAnvil.id]: "Anvil",
};

export function getChainName(chainId: number): string {
  return CHAIN_NAMES[chainId] || `Chain ${chainId}`;
}
