import {
  ArrowRight,
  Filter,
  ShieldCheck,
  Vault,
  WalletCards,
} from "lucide-react";
import { Link } from "react-router-dom";
import { useVaultsModel } from "@/hooks/useVaultsModel";
import { EmptyState, HeroMetric, MetricCard } from "@/components/shared";
import { VaultStatus, SummaryRow } from "./components";

export default function VaultsPage() {
  const {
    filteredVaults,
    availableAssets,
    availableGuardians,
    filters,
    isVaultDepositsPaused,
    isVaultCreationPaused,
    metrics,
    guardianRoutingStatus,
    guardianRoutingSubtitle,
    registryVisibilityStatus,
    registryVisibilitySubtitle,
    vaultExplorerStatus,
    vaultExplorerSubtitle,
    setAssetFilter,
    setGuardianFilter,
    setStatusFilter,
    capabilities,
  } = useVaultsModel();

  const creationAccessValue = isVaultCreationPaused ? "Paused" : "Enabled";
  const creationSummaryStatus = isVaultCreationPaused ? "Paused" : "Available";
  const creationSummaryTone = isVaultCreationPaused ? "warning" : "success";
  const creationAssetsDescription = isVaultCreationPaused
    ? "New vault creation is paused by ProtocolCore, so no new vaults can be deployed right now."
    : "New vaults can be created and deployed while protocol creation remains enabled.";

  const depositAccessValue = isVaultDepositsPaused ? "Paused" : "Enabled";
  const depositSummaryStatus = isVaultDepositsPaused ? "Paused" : "Available";
  const depositSummaryTone = isVaultDepositsPaused ? "warning" : "success";
  const depositAccessSubtitle = isVaultDepositsPaused
    ? "Vault deposits are currently paused at protocol level."
    : "Vault deposits are enabled, subject to each vault's own state.";
  const depositAssetsDescription = isVaultDepositsPaused
    ? "Deposits are paused by ProtocolCore, so users cannot deposit supported assets right now."
    : "Users may deposit supported assets into active vaults while protocol deposits remain enabled.";
  const mintSharesDescription = isVaultDepositsPaused
    ? "Minting shares is paused because ProtocolCore has vault deposits disabled."
    : "Vault shares may be minted according to ERC4626 behavior while protocol deposits remain enabled.";
  const withdrawAssetsStatus = metrics.totalVaults > 0 ? "Available" : "No Vaults";
  const withdrawAssetsTone =
    metrics.totalVaults > 0 ? "success" : ("neutral" as const);
  const withdrawAssetsDescription = metrics.totalVaults > 0
    ? "Withdrawals are available in active vaults and remain subject to vault and ownership constraints."
    : "No registered vaults are available yet, so withdrawals cannot be exercised from this module.";
  const redeemSharesStatus = metrics.totalVaults > 0 ? "Available" : "No Vaults";
  const redeemSharesTone =
    metrics.totalVaults > 0 ? "success" : ("neutral" as const);
  const redeemSharesDescription = metrics.totalVaults > 0
    ? "Users may redeem shares for the underlying asset when vault rules allow it."
    : "No registered vaults are available yet, so redemptions cannot be exercised from this module.";
  const guardianExecutionStatus = capabilities.canExecuteStrategy
    ? "Available"
    : "Restricted";
  const guardianExecutionTone = capabilities.canExecuteStrategy
    ? "success"
    : "warning";
  const guardianExecutionDescription = capabilities.canExecuteStrategy
    ? "Guardian-linked vaults may execute strategies through the router when the connected wallet has guardian access."
    : "Strategy execution is restricted to guardian wallets with the proper on-chain role.";

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

        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          <HeroMetric
            label="Total Vaults"
            value={String(metrics.totalVaults)}
          />
          <HeroMetric
            label="Active Vaults"
            value={String(metrics.activeVaults)}
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
          value={vaultExplorerStatus}
          subtitle={vaultExplorerSubtitle}
          icon={<Vault className="h-5 w-5" />}
        />
        <MetricCard
          title="Deposit Access"
          value={depositAccessValue}
          subtitle={depositAccessSubtitle}
          icon={<WalletCards className="h-5 w-5" />}
        />
        <MetricCard
          title="Guardian Routing"
          value={guardianRoutingStatus}
          subtitle={guardianRoutingSubtitle}
          icon={<ShieldCheck className="h-5 w-5" />}
        />
        <MetricCard
          title="Registry Visibility"
          value={registryVisibilityStatus}
          subtitle={registryVisibilitySubtitle}
          icon={<Vault className="h-5 w-5" />}
        />
      </section>

      <section className="card">
        <div className="card-header">Vault Filters</div>

        <div className="card-content grid gap-4 lg:grid-cols-3">
          <div>
            <label className="text-sm text-text-secondary">Asset</label>
            <select
              value={filters.asset}
              onChange={(e) => setAssetFilter(e.target.value)}
              className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
            >
              <option value="All Assets">All Assets</option>
              {availableAssets.map((asset) => (
                <option key={asset} value={asset}>
                  {asset}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="text-sm text-text-secondary">Guardian</label>
            <input
              type="text"
              list="vault-guardian-options"
              value={filters.guardian}
              placeholder="Search guardian address"
              onChange={(e) => setGuardianFilter(e.target.value)}
              className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
            />
            <datalist id="vault-guardian-options">
              {availableGuardians.map((guardian) => (
                <option key={guardian} value={guardian} />
              ))}
            </datalist>
          </div>

          <div>
            <label className="text-sm text-text-secondary">Status</label>
            <select
              value={filters.status}
              onChange={(e) =>
                setStatusFilter(e.target.value as "All" | "Active" | "Inactive")
              }
              className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
            >
              <option value="All">All</option>
              <option value="Active">Active</option>
              <option value="Inactive">Inactive</option>
            </select>
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
              {filteredVaults.length > 0 ? (
                filteredVaults.map((vault) => (
                  <tr key={vault.fullAddress} className="border-b border-border">
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
                        to={`/vaults/${vault.fullAddress}`}
                        className="inline-flex items-center gap-2 text-sm font-medium text-primary hover:underline"
                      >
                        View Details
                        <ArrowRight className="h-4 w-4" />
                      </Link>
                      {/* TODO: navegar a /vaults/:vaultAddress */}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={6} className="px-6 py-10">
                    <EmptyState
                      title="No registered vaults available"
                      description="There are no vaults matching the current filters for this network."
                    />
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section className="grid gap-6 lg:grid-cols-2">
        <div className="card">
          <div className="card-header">Vault Operations Summary</div>

          <div className="card-content space-y-4">
            <SummaryRow
              title="Vault Creation"
              description={creationAssetsDescription}
              status={creationSummaryStatus}
              tone={creationSummaryTone}
            />
            <SummaryRow
              title="Deposit Assets"
              description={depositAssetsDescription}
              status={depositSummaryStatus}
              tone={depositSummaryTone}
            />
            <SummaryRow
              title="Mint Shares"
              description={mintSharesDescription}
              status={depositSummaryStatus}
              tone={depositSummaryTone}
            />
            <SummaryRow
              title="Withdraw Assets"
              description={withdrawAssetsDescription}
              status={withdrawAssetsStatus}
              tone={withdrawAssetsTone}
            />
            <SummaryRow
              title="Redeem Shares"
              description={redeemSharesDescription}
              status={redeemSharesStatus}
              tone={redeemSharesTone}
            />
            <SummaryRow
              title="Guardian Execution"
              description={guardianExecutionDescription}
              status={guardianExecutionStatus}
              tone={guardianExecutionTone}
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

            {capabilities.canCreateVault ? (
              <Link
                to="/vaults/guardian-tools"
                className={[
                  "block w-full rounded-lg px-4 py-2 text-center text-sm font-medium transition",
                  capabilities.canCreateVault
                    ? "bg-primary text-white hover:bg-primary-hover"
                    : "cursor-not-allowed bg-primary/50 text-white opacity-50",
                ].join(" ")}
              >
                Open Guardian Vault Tools
              </Link>
            ) : (
              <div className="rounded-2xl border border-yellow-200 bg-yellow-50 px-4 py-4">
                <p className="text-sm font-medium text-yellow-800">
                  Guardian Tools Hidden
                </p>
                <p className="mt-1 text-sm leading-6 text-yellow-700">
                  Guardian vault tooling is only available to wallets with active
                  guardian access.
                </p>
              </div>
            )}
            <Link
              to="/vaults/positions"
              className="block w-full rounded-lg border border-border px-4 py-2 text-center text-sm font-medium text-text-primary transition hover:bg-gray-50"
            >
              View My Positions
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
