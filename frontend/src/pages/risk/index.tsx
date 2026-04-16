import {
  AlertTriangle,
  PauseCircle,
  PlayCircle,
  ShieldCheck,
  Waves,
} from "lucide-react";
import { useRiskModel } from "@/hooks/useRiskModel";
import { HeroMetric, MetricCard } from "@/components/shared";
import { HealthBadge, ConfigField } from "./components";

function formatExecutionStatus(value: "monitoring" | "paused") {
  return value === "monitoring" ? "Monitoring" : "Paused";
}

export default function RiskPage() {
  const { metrics, assets, capabilities } = useRiskModel();

  return (
    <div className="space-y-8">
      <section className="rounded-3xl bg-gradient-to-r from-primary to-primary-light px-8 py-10 text-white shadow-card">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-100">
          Risk Monitoring
        </p>

        <h1 className="mt-4 text-3xl font-semibold leading-tight lg:text-4xl">
          Review protocol execution safety, asset health signals and emergency
          control states.
        </h1>

        <p className="mt-4 max-w-3xl text-sm leading-7 text-blue-50 lg:text-base">
          Risk monitoring protects strategy execution through asset validation,
          price feed checks and emergency pause controls.
        </p>

        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <HeroMetric
            label="Execution Status"
            value={formatExecutionStatus(metrics.executionStatus)}
          />
          <HeroMetric
            label="Configured Assets"
            value={String(metrics.configuredAssets)}
          />
          <HeroMetric
            label="Healthy Assets"
            value={String(metrics.healthyAssets)}
          />
          <HeroMetric
            label="Risk Alerts"
            value={String(metrics.riskAlerts)}
          />
        </div>
      </section>

      <section className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          title="Execution Engine"
          value="Observed"
          subtitle="Execution state is monitored before strategy routing."
          icon={<ShieldCheck className="h-5 w-5" />}
        />
        <MetricCard
          title="Asset Validation"
          value="Enabled"
          subtitle="Configured assets are checked against feed and health rules."
          icon={<Waves className="h-5 w-5" />}
        />
        <MetricCard
          title="Emergency Controls"
          value="Restricted"
          subtitle="Pause and resume actions are limited to operational capabilities."
          icon={<PauseCircle className="h-5 w-5" />}
        />
        <MetricCard
          title="Price Monitoring"
          value="Live"
          subtitle="Validated price checks support execution gating."
          icon={<AlertTriangle className="h-5 w-5" />}
        />
      </section>

      <section className="grid gap-6 xl:grid-cols-[0.95fr,1.05fr]">
        <div className="card">
          <div className="card-header">Execution Controls</div>

          <div className="card-content space-y-5">
            <div className="rounded-2xl border border-border px-4 py-4">
              <p className="text-sm font-semibold text-text-primary">
                Pause Strategy Execution
              </p>
              <p className="mt-1 text-sm leading-6 text-text-secondary">
                Emergency operators may pause strategy execution across the
                protocol when risk conditions require immediate intervention.
              </p>

              <button
                className="btn-primary mt-4 inline-flex items-center gap-2 disabled:cursor-not-allowed disabled:opacity-50"
                disabled={!capabilities.canPauseRiskExecution}
              >
                <PauseCircle className="h-4 w-4" />
                Pause Execution
              </button>
            </div>

            <div className="rounded-2xl border border-border px-4 py-4">
              <p className="text-sm font-semibold text-text-primary">
                Resume Strategy Execution
              </p>
              <p className="mt-1 text-sm leading-6 text-text-secondary">
                Managers may resume execution after risk conditions have been
                reviewed and cleared.
              </p>

              <button
                className="btn-secondary mt-4 inline-flex items-center gap-2 disabled:cursor-not-allowed disabled:opacity-50"
                disabled={!capabilities.canResumeRiskExecution}
              >
                <PlayCircle className="h-4 w-4" />
                Resume Execution
              </button>
            </div>

            <div className="rounded-2xl border border-border bg-yellow-50 px-4 py-4">
              <p className="text-sm font-medium text-yellow-800">
                Execution Governance
              </p>
              <p className="mt-1 text-sm leading-6 text-yellow-700">
                Pause and resume authority should remain visibly separated across
                emergency and manager capability layers.
              </p>
            </div>

            {/* TODO: conectar pauseAdapterExecution() */}
            {/* TODO: conectar unpauseAdapterExecution() */}
          </div>
        </div>

        <div className="card">
          <div className="card-header">Asset Health</div>

          <div className="overflow-x-auto">
            <table className="min-w-full border-collapse">
              <thead>
                <tr className="border-b border-border bg-gray-50 text-left">
                  <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                    Asset
                  </th>
                  <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                    Feed
                  </th>
                  <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                    Heartbeat
                  </th>
                  <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                    Stable Asset
                  </th>
                  <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                    Depeg Range
                  </th>
                  <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                    Health Status
                  </th>
                  <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                    Validated Price
                  </th>
                </tr>
              </thead>

              <tbody>
                {assets.map((asset) => (
                  <tr key={asset.asset} className="border-b border-border">
                    <td className="px-6 py-4 text-sm font-medium text-text-primary">
                      {asset.asset}
                    </td>
                    <td className="px-6 py-4 text-sm text-text-secondary">
                      {asset.feed}
                    </td>
                    <td className="px-6 py-4 text-sm text-text-secondary">
                      {asset.heartbeat}
                    </td>
                    <td className="px-6 py-4 text-sm text-text-secondary">
                      {asset.stable}
                    </td>
                    <td className="px-6 py-4 text-sm text-text-secondary">
                      {asset.range}
                    </td>
                    <td className="px-6 py-4">
                      <HealthBadge value={asset.health} />
                    </td>
                    <td className="px-6 py-4 text-sm text-text-secondary">
                      {asset.price}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {assets.length === 0 && (
            <div className="card-content">
              <p className="text-sm text-text-secondary">
                No configured assets available.
              </p>
            </div>
          )}
        </div>
      </section>

      <section className="card">
        <div className="card-header">Asset Configuration</div>

        <div className="card-content grid gap-5 lg:grid-cols-2">
          <ConfigField label="Asset Address" placeholder="0x..." />
          <ConfigField label="Price Feed" placeholder="Chainlink feed address" />
          <ConfigField label="Heartbeat" placeholder="e.g. 3600" />
          <ConfigField label="Stable Asset" placeholder="true / false" />
          <ConfigField label="Depeg Min BPS" placeholder="e.g. 9800" />
          <ConfigField label="Depeg Max BPS" placeholder="e.g. 10200" />

          <div className="lg:col-span-2">
            <button className="btn-primary disabled:cursor-not-allowed disabled:opacity-50">
              Update Asset Configuration
            </button>
          </div>

          {/* TODO: conectar setAssetConfig(...) */}
          {/* TODO: modelar enabled como toggle visual */}
        </div>
      </section>
    </div>
  );
}