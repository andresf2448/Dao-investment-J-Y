import { mainnet, sepolia } from "wagmi/chains";

export const SUPPORTED_CHAINS = [sepolia, mainnet] as const;

export const CHAIN_NAMES: Record<number, string> = {
  [mainnet.id]: "Ethereum",
  [sepolia.id]: "Sepolia",
};

export function getChainName(chainId: number): string {
  return CHAIN_NAMES[chainId] || `Chain ${chainId}`;
}
