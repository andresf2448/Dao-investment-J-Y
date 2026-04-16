import { http, createPublicClient, formatEther, parseEther } from "viem";
import { sepolia, mainnet, anvil } from "wagmi/chains";

export function getPublicClient(chainId: number = sepolia.id) {
  const chain = [sepolia, mainnet, anvil].find((c) => c.id === chainId) || sepolia;
  return createPublicClient({
    chain,
    transport: http(),
  });
}

export { formatEther, parseEther };
