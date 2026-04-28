export const networksList: Record<number, string> = {
  1: "Ethereum Mainnet",
  11155111: "Sepolia",
  31337: "Anvil",
};

export const ERC20_DEFAULT = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

const networkNamesByChainId: Record<number, Record<string, string>> = {
  1: {
    "0xd9003177dC465aAA89e20678675dca7FA5f5CAD5": "USDT",
  },
  11155111: {
    "0x9e1aE7c8Bf1b3C2b5c9A4d8F6e7B2a1C3D4E5F6": "USDC",
  },
  31337: {
    "0x5FbDB2315678afecb367f032d93F642f64180aa3": "USDT",
    "0x172076E0166D1F9Cc711C77Adf8488051744980C": "USDC",
    "0x8fC8CFB7f7362E44E472c690A6e025B80E406458": "TEST"
  },
};

export const getNetworkNameByContract = (chainId: number): string => {
  return networksList[chainId] ?? `Chain ${chainId}`;
};

export function getContractNameByNetwork(chainId: number, contractAddress: string): string {
  return networkNamesByChainId[chainId]?.[contractAddress] ?? contractAddress;
}

export function getNetworkName(chainId: number): string {
  return networksList[chainId] ?? `Chain ${chainId}`;
}
