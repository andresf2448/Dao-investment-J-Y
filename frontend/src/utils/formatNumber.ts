export function formatNumber(value: string | number, decimals: number = 2): string {
  const num = typeof value === "string" ? parseFloat(value) : value;
  if (isNaN(num)) return "—";

  if (num >= 1_000_000) {
    return `${(num / 1_000_000).toFixed(1)}M`;
  }
  if (num >= 1_000) {
    return `${(num / 1_000).toFixed(1)}K`;
  }

  return num.toLocaleString("en-US", {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
}

export function formatPercentage(value: number, decimals: number = 2): string {
  if (isNaN(value)) return "—";
  return `${value.toFixed(decimals)}%`;
}

export function formatBPS(value: number): string {
  if (isNaN(value)) return "—";
  return `${(value / 100).toFixed(2)}%`;
}
