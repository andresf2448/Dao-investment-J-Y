const TOKEN_SYMBOLS: Record<string, string> = {
  ETH: "ETH",
  WETH: "WETH",
  USDC: "USDC",
  USDT: "USDT",
  DAI: "DAI",
  GOV: "GOV",
};

export function formatCurrency(
  value: string | number,
  symbol: string = "USD",
  decimals: number = 2
): string {
  const num = typeof value === "string" ? parseFloat(value) : value;
  if (isNaN(num)) return "—";

  const formatted = num.toLocaleString("en-US", {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });

  return `${formatted} ${symbol}`;
}

export function formatTokenAmount(
  value: string | number,
  symbol: string,
  decimals: number = 18
): string {
  const num = typeof value === "string" ? parseFloat(value) : value;
  if (isNaN(num)) return "—";

  const adjusted = num / Math.pow(10, decimals);
  const displayDecimals = adjusted < 1 ? 6 : 2;

  return `${adjusted.toLocaleString("en-US", {
    minimumFractionDigits: displayDecimals,
    maximumFractionDigits: displayDecimals,
  })} ${symbol}`;
}

export function parseTokenAmount(value: string, decimals: number = 18): bigint {
  const num = parseFloat(value);
  if (isNaN(num)) return BigInt(0);
  return BigInt(Math.floor(num * Math.pow(10, decimals)));
}
