import {
  ArrowRight,
  Filter,
  ShieldCheck,
  Vault,
  WalletCards,
} from "lucide-react";
import { Link } from "react-router-dom";
import { useVaultsModel } from "@/hooks/useVaultsModel";
import { HeroMetric, MetricCard } from "@/components/shared";
import { VaultStatus, SummaryRow } from "./components";

export default function VaultsPage() {
  const {
    filteredVaults,
    metrics,
    setAssetFilter,
    setGuardianFilter,
    setStatusFilter,
    capabilities,
  } = useVaultsModel();

  return (
    <div className="space-y-8">
      <section className="rounded-3xl bg-gradient-to-r from-primary to-primary-light px-8 py-10 text-white shadow-card">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-100">
          Vault Infrastructure
        </p>

        <h1 className="mt-4 text-3xl font-semibold leading-tight lg:text-4xl">
          Explore active vaults, review asset coverage and access vault-level
          operations.
        </h1>

        <p className="mt-4 max-w-3xl text-sm leading-7 text-blue-50 lg:text-base">
          Vault infrastructure is registered onchain and linked to guardians,
          supported assets and protocol-level execution controls.
        </p>

        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <HeroMetric
            label="Total Vaults"
            value={String(metrics.totalVaults)}
          />
          <HeroMetric
            label="Active Vaults"
            value={String(metrics.activeVaults)}
          />
          <HeroMetric
            label="Assets Covered"
            value={String(metrics.assetsCovered)}
          />
          <HeroMetric
            label="Guardian Coverage"
            value={String(metrics.guardianCoverage)}
          />
        </div>
      </section>

      <section className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          title="Vault Explorer"
          value="Live"
          subtitle="Registered protocol vaults are visible from this module."
          icon={<Vault className="h-5 w-5" />}
        />
        <MetricCard
          title="Deposit Access"
          value="Enabled"
          subtitle="Vault deposits depend on protocol-level and vault-level state."
          icon={<WalletCards className="h-5 w-5" />}
        />
        <MetricCard
          title="Guardian Routing"
          value="Linked"
          subtitle="Guardian-linked deployment and operation model."
          icon={<ShieldCheck className="h-5 w-5" />}
        />
        <MetricCard
          title="Registry Visibility"
          value="Tracked"
          subtitle="Vault identity, asset and guardian relationships are available."
          icon={<Vault className="h-5 w-5" />}
        />
      </section>

      <section className="card">
        <div className="card-header">Vault Filters</div>

        <div className="card-content grid gap-4 lg:grid-cols-4">
          <div>
            <label className="text-sm text-text-secondary">Asset</label>
            <select
              onChange={(e) => setAssetFilter(e.target.value)}
              className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
            >
              <option>All Assets</option>
              <option>USDC</option>
              <option>DAI</option>
              <option>ETH</option>
            </select>
          </div>

          <div>
            <label className="text-sm text-text-secondary">Guardian</label>
            <input
              type="text"
              placeholder="Search guardian address"
              onChange={(e) => setGuardianFilter(e.target.value)}
              className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
            />
          </div>

          <div>
            <label className="text-sm text-text-secondary">Status</label>
            <select
              onChange={(e) =>
                setStatusFilter(e.target.value as "All" | "Active" | "Inactive")
              }
              className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
            >
              <option>All</option>
              <option>Active</option>
              <option>Inactive</option>
            </select>
          </div>

          <div className="flex items-end">
            <button className="btn-secondary w-full">
              <span className="inline-flex items-center gap-2">
                <Filter className="h-4 w-4" />
                Apply Filters
              </span>
            </button>
          </div>
        </div>
      </section>

      <section className="card">
        <div className="card-header">Registered Vaults</div>

        <div className="overflow-x-auto">
          <table className="min-w-full border-collapse">
            <thead>
              <tr className="border-b border-border bg-gray-50 text-left">
                <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                  Vault Address
                </th>
                <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                  Asset
                </th>
                <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                  Guardian
                </th>
                <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                  Registered At
                </th>
                <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                  Status
                </th>
                <th className="px-6 py-4 text-xs font-semibold uppercase tracking-[0.14em] text-text-secondary">
                  Action
                </th>
              </tr>
            </thead>

            <tbody>
              {filteredVaults.map((vault) => (
                <tr key={vault.address} className="border-b border-border">
                  <td className="px-6 py-4 text-sm font-medium text-text-primary">
                    {vault.address}
                  </td>
                  <td className="px-6 py-4 text-sm text-text-primary">
                    {vault.asset}
                  </td>
                  <td className="px-6 py-4 text-sm text-text-secondary">
                    {vault.guardian}
                  </td>
                  <td className="px-6 py-4 text-sm text-text-secondary">
                    {vault.registeredAt}
                  </td>
                  <td className="px-6 py-4">
                    <VaultStatus status={vault.status} />
                  </td>
                  <td className="px-6 py-4">
                    <Link
                      to={`/vaults/${vault.address}`}
                      className="inline-flex items-center gap-2 text-sm font-medium text-primary hover:underline"
                    >
                      View Details
                      <ArrowRight className="h-4 w-4" />
                    </Link>
                    {/* TODO: navegar a /vaults/:vaultAddress */}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* TODO:
          - usar getAllVaults() desde VaultRegistry
          - enriquecer filas con getVaultDetail(vault)
          - resolver status real con isActiveVault(vault)
        */}
      </section>

      <section className="grid gap-6 lg:grid-cols-2">
        <div className="card">
          <div className="card-header">Vault Operations Summary</div>

          <div className="card-content space-y-4">
            <SummaryRow
              title="Deposit Assets"
              description="Users may deposit supported assets into active vaults."
              status="Available"
              tone="success"
            />
            <SummaryRow
              title="Mint Shares"
              description="Vault shares may be minted according to ERC4626 behavior."
              status="Available"
              tone="success"
            />
            <SummaryRow
              title="Withdraw Assets"
              description="Withdrawals remain subject to vault and ownership constraints."
              status="Available"
              tone="success"
            />
            <SummaryRow
              title="Redeem Shares"
              description="Users may redeem shares for underlying assets."
              status="Available"
              tone="success"
            />
            <SummaryRow
              title="Guardian Execution"
              description="Guardian operations require an active guardian-linked vault."
              status="Restricted"
              tone="warning"
            />
          </div>
        </div>

        <div className="card">
          <div className="card-header">Guardian Vault Tools</div>

          <div className="card-content space-y-4">
            <p className="text-sm leading-7 text-text-secondary">
              Guardian-linked tools support vault deployment, pair checks and
              future execution workflows for authorized operators.
            </p>

            <div className="rounded-2xl border border-border bg-gray-50 px-4 py-4">
              <p className="text-sm font-medium text-text-primary">
                Create New Vault
              </p>
              <p className="mt-1 text-sm leading-6 text-text-secondary">
                Active guardians may deploy vaults for supported assets when
                vault creation is enabled.
              </p>
            </div>

            <div className="rounded-2xl border border-border bg-gray-50 px-4 py-4">
              <p className="text-sm font-medium text-text-primary">
                Predicted Address & Pair Availability
              </p>
              <p className="mt-1 text-sm leading-6 text-text-secondary">
                Use deterministic deployment checks to confirm whether a vault
                already exists for a guardian and asset pair.
              </p>
            </div>

            <Link
              to="/vaults/guardian-tools"
              className={[
                "block w-full rounded-lg px-4 py-2 text-center text-sm font-medium transition",
                capabilities.canCreateVault
                  ? "bg-primary text-white hover:bg-primary-hover"
                  : "pointer-events-none cursor-not-allowed bg-primary/50 text-white opacity-50",
              ].join(" ")}
            >
              Open Guardian Vault Tools
            </Link>
            <Link
              to="/vaults/positions"
              className="block w-full rounded-lg border border-border px-4 py-2 text-center text-sm font-medium text-text-primary transition hover:bg-gray-50"
            >
              View My Positions
            </Link>
            {/* TODO: llevar a /vaults/guardian-tools */}
          </div>
        </div>
      </section>
    </div>
  );
}
