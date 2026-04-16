import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { anvil, sepolia } from "wagmi/chains";

const config = getDefaultConfig({
  appName: "DaoInversionesJ&Y",
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || "",
  // projectId: "",
  chains: [anvil, sepolia]
})

export default config;