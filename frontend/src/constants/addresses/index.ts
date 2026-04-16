import { PROTOCOL_ADDRESSES, type ProtocolContract } from "./protocol";

export { PROTOCOL_ADDRESSES, type ProtocolContract };

export const CHAIN_ID = {
  MAINNET: 1,
  SEPOLIA: 11155111,
  LOCAL: 31337,
} as const;

export const SUPPORTED_CHAINS = [CHAIN_ID.SEPOLIA, CHAIN_ID.MAINNET] as const;
