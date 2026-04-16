import { http, createConfig } from "wagmi";
import { anvil, sepolia, mainnet } from "wagmi/chains";

export const wagmiConfig = createConfig({
  chains: [sepolia, mainnet, anvil],
  transports: {
    [sepolia.id]: http(),
    [mainnet.id]: http(),
    [anvil.id]: http(),
  },
});
