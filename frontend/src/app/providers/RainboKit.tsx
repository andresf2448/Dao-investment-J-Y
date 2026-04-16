import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { type ReactNode, useState } from "react";
import { WagmiProvider } from "wagmi";
import { lightTheme, darkTheme, RainbowKitProvider } from "@rainbow-me/rainbowkit";
import config from "@/config/rainbowKitConfig";
import "@rainbow-me/rainbowkit/styles.css";

export function Provider(props: { children: ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider
          theme={darkTheme({
            borderRadius: "medium",
          })}
          locale="en-US"
        >
          {props.children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
