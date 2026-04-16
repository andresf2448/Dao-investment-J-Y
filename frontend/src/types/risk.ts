export type ExecutionStatus = "monitoring" | "paused";
export type HealthStatus = "Healthy" | "Monitoring" | "Unhealthy";

export interface RiskAsset {
  asset: string;
  feed: string;
  heartbeat: string;
  stable: string;
  range: string;
  health: HealthStatus;
  price: string;
}

export interface RiskMetrics {
  executionStatus: ExecutionStatus;
  configuredAssets: number;
  healthyAssets: number;
  riskAlerts: number;
}
