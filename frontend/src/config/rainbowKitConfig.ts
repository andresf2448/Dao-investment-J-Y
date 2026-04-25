import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { sepolia } from "wagmi/chains";
import { localAnvil } from "@/lib/chains";

const config = getDefaultConfig({
  appName: "DaoInversionesJ&Y",
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || "",
  chains: [localAnvil, sepolia],
});

export default config;