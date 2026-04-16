import { Coins, Landmark, PieChart, Wallet } from "lucide-react";
import { Link } from "react-router-dom";
import { useTreasuryModel } from "@/hooks/useTreasuryModel";
import { HeroMetric, MetricCard, NoteRow } from "@/components/shared";
import { CategoryBadge, VisibilityBadge, MiniSummaryCard } from "./components";

export default function TreasuryPage() {
  const { assets, metrics, capabilities } = useTreasuryModel();

  return (
    <div className="space-y-8">
      <section className="rounded-3xl bg-gradient-to-r from-primary to-primary-light px-8 py-10 text-white shadow-card">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-100">
          Treasury Layer
        </p>

        <h1 className="mt-4 text-3xl font-semibold leading-tight lg:text-4xl">
          Monitor treasury balances, protocol reserves and asset composition
          across native and ERC20 holdings.
        </h1>

        <p className="mt-4 max-w-3xl text-sm leading-7 text-blue-50 lg:text-base">
          Treasury visibility supports governance, operational awareness and
          controlled withdrawal flows under explicit protocol permissions.
        </p>

        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <HeroMetric label="Native Balance" value={metrics.nativeBalance} />
          <HeroMetric
            label="Tracked ERC20 Assets"
            value={String(metrics.trackedErc20Assets)}
          />
          <HeroMetric
            label="DAO Asset Exposure"
            value={metrics.daoAssetExposure}
          />
          <HeroMetric
            label="Operational Liquidity"
            value={metrics.operationalLiquidity}
          />
        </div>
      </section>

      <section className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          title="Treasury Visibility"
          value="Live"
          subtitle="Treasury balances are surfaced through overview-level reads."
          icon={<Landmark className="h-5 w-5" />}
        />
        <MetricCard
          title="Native Exposure"
          value="Tracked"
          subtitle="Native protocol reserves are displayed independently."
          icon={<Wallet className="h-5 w-5" />}
        />
        <MetricCard
          title="ERC20 Composition"
          value="Visible"
          subtitle="Tracked ERC20 balances are grouped and classified."
          icon={<Coins className="h-5 w-5" />}
        />
        <MetricCard
          title="Treasury Composition"
          value="Balanced"
          subtitle="Asset allocation is available for executive review."
          icon={<PieChart className="h-5 w-5" />}
        />
      </section>

      <section className="grid gap-6 xl:grid-cols-[1.15fr,0.85fr]">
        <div className="card">
          <div className="card-header">Asset Allocation</div>

          <div className="overflow-x-auto">
            <table className="min-w-full border-collapse">
              <thead>
                <tr className="border-b border-border bg-gray-50 text-left">
                  <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                    Token
                  </th>
                  <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                    Type
                  </th>
                  <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                    Balance
                  </th>
                  <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                    Category
                  </th>
                  <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                    Visibility
                  </th>
                </tr>
              </thead>

              <tbody>
                {assets.map((asset) => (
                  <tr
                    key={`${asset.token}-${asset.type}`}
                    className="border-b border-border"
                  >
                    <td className="px-6 py-4 text-sm font-medium text-text-primary">
                      {asset.token}
                    </td>
                    <td className="px-6 py-4 text-sm text-text-secondary">
                      {asset.type}
                    </td>
                    <td className="px-6 py-4 text-sm text-text-secondary">
                      {asset.balance}
                    </td>
                    <td className="px-6 py-4">
                      <CategoryBadge category={asset.category} />
                    </td>
                    <td className="px-6 py-4">
                      <VisibilityBadge value={asset.visibility} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {assets.length === 0 && (
            <div className="card-content">
              <p className="text-sm text-text-secondary">
                No treasury assets available.
              </p>
            </div>
          )}
        </div>

        <div className="space-y-6">
          <div className="card">
            <div className="card-header">Treasury Notes</div>

            <div className="card-content space-y-4">
              <NoteRow
                title="DAO Asset Controls"
                description="DAO-classified assets follow stricter withdrawal and governance-driven handling."
              />
              <NoteRow
                title="Non-DAO Asset Controls"
                description="Non-DAO assets may be subject to distinct sweep and operational rules."
              />
              <NoteRow
                title="Native Treasury Visibility"
                description="Native reserves are surfaced independently from ERC20 asset balances."
              />
            </div>
          </div>

          <div className="card">
            <div className="card-header">Treasury Actions</div>

            <div className="card-content space-y-4">
              <p className="text-sm leading-7 text-text-secondary">
                Treasury operations are permissioned and separated from overview
                visibility. Use the dedicated operations view for restricted
                treasury actions.
              </p>
              <Link
                to="/treasury/operations"
                className={[
                  "block w-full rounded-lg px-4 py-2 text-center text-sm font-medium transition",
                  capabilities.canOpenTreasuryOperations
                    ? "bg-primary text-white hover:bg-primary-hover"
                    : "pointer-events-none cursor-not-allowed bg-primary/50 text-white opacity-50",
                ].join(" ")}
              >
                Open Treasury Operations
              </Link>
              {/* TODO: navegar a /treasury/operations */}
            </div>
          </div>
        </div>
      </section>

      <section className="grid gap-6 lg:grid-cols-3">
        <MiniSummaryCard
          title="Native Reserve"
          value={metrics.nativeBalance}
          subtitle="Displayed from native balance visibility"
        />
        <MiniSummaryCard
          title="Tracked ERC20 Assets"
          value={`${metrics.trackedErc20Assets} Assets`}
          subtitle="Treasury ERC20 balances are classified and surfaced"
        />
        <MiniSummaryCard
          title="Asset Category Model"
          value="DAO / Non-DAO"
          subtitle="Classification is derived from protocol support rules"
        />
      </section>
    </div>
  );
}
