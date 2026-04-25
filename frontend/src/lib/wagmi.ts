import { http, createConfig } from "wagmi";
import { mainnet, sepolia } from "wagmi/chains";
import { localAnvil } from "./chains";

export const wagmiConfig = createConfig({
  chains: [localAnvil, sepolia, mainnet],
  transports: {
    [localAnvil.id]: http(),
    [sepolia.id]: http(),
    [mainnet.id]: http(),
  },
});
