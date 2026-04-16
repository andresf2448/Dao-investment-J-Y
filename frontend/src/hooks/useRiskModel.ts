import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type RiskExecutionStatus = "monitoring" | "paused";

export type RiskAssetHealth = "Healthy" | "Monitoring" | "Critical";

export type RiskAsset = {
  asset: string;
  feed: string;
  heartbeat: string;
  stable: "Yes" | "No";
  range: string;
  health: RiskAssetHealth;
  price: string;
};

export type RiskMetrics = {
  executionStatus: RiskExecutionStatus;
  configuredAssets: number;
  healthyAssets: number;
  riskAlerts: number;
};

export type RiskModel = {
  metrics: RiskMetrics;
  assets: RiskAsset[];
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useRiskModel(): RiskModel {
  const capabilities = useProtocolCapabilities();

  // ===== MOCK ASSETS =====
  const assets: RiskAsset[] = [
    {
      asset: "USDC",
      feed: "0xFeed...0011",
      heartbeat: "3600s",
      stable: "Yes",
      range: "0.98 - 1.02",
      health: "Healthy",
      price: "$1.00",
    },
    {
      asset: "DAI",
      feed: "0xFeed...00A2",
      heartbeat: "3600s",
      stable: "Yes",
      range: "0.98 - 1.02",
      health: "Monitoring",
      price: "$0.999",
    },
    {
      asset: "ETH",
      feed: "0xFeed...09F1",
      heartbeat: "1800s",
      stable: "No",
      range: "N/A",
      health: "Healthy",
      price: "$3,420",
    },
  ];

  const metrics: RiskMetrics = {
    executionStatus: "monitoring",
    configuredAssets: assets.length,
    healthyAssets: assets.filter((asset) => asset.health === "Healthy").length,
    riskAlerts: assets.filter((asset) => asset.health !== "Healthy").length,
  };

  // ===== FUTURO =====
  // TODO:
  // metrics.executionStatus -> RiskManager.executionPaused
  // metrics.configuredAssets -> total de assets configurados en RiskManager
  // metrics.healthyAssets -> conteo usando RiskManager.isAssetHealthy(asset)
  // metrics.riskAlerts -> assets no saludables / execution paused
  //
  // assets:
  // - feed, heartbeat, stable, range -> RiskManager.getAssetConfig(asset)
  // - price -> RiskManager.getValidatedPrice(asset)
  // - health -> RiskManager.isAssetHealthy(asset)
  //
  // acciones futuras desde la vista:
  // - RiskManager.pauseAdapterExecution()
  // - RiskManager.unpauseAdapterExecution()
  // - RiskManager.setAssetConfig(...)
  //
  // capabilities:
  // - canPauseRiskExecution
  // - canResumeRiskExecution

  return {
    metrics,
    assets,
    capabilities,
  };
}