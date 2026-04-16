import { useParams } from "react-router-dom";
import { ShieldCheck, Vault, WalletCards, Zap } from "lucide-react";
import { useVaultDetailModel } from "@/hooks/useVaultDetailModel";
import { HeroMetric, MetricCard } from "@/components/shared";
import { SummaryStat, MetaRow, ActionField } from "../";

export default function VaultDetailPage() {
  const { vaultAddress } = useParams();
  const { 
    vault,
    position,
    controls,
    capabilities 
  } = useVaultDetailModel(vaultAddress);

  return (
    <div className="space-y-8">
      <section className="rounded-3xl bg-gradient-to-r from-primary to-primary-light px-8 py-10 text-white shadow-card">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-100">
          Vault Details
        </p>

        <h1 className="mt-4 text-3xl font-semibold leading-tight lg:text-4xl">
          Review vault state, user position and asset-level operations.
        </h1>

        <p className="mt-4 max-w-3xl text-sm leading-7 text-blue-50 lg:text-base">
          Vault activity is tied to guardian-linked infrastructure, protocol
          controls and strategy execution safety checks.
        </p>

        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <HeroMetric label="Vault Address" value={vault.address} />
          <HeroMetric label="Asset" value={vault.asset} />
          <HeroMetric label="Guardian" value={vault.guardian} />
          <HeroMetric label="Status" value={vault.status} />
        </div>
      </section>

      <section className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          title="Registered At"
          value={vault.registeredAt}
          subtitle="Vault registration reference date"
          icon={<Vault className="h-5 w-5" />}
        />
        <MetricCard
          title="Decimals"
          value={String(vault.decimals)}
          subtitle="Underlying asset precision"
          icon={<WalletCards className="h-5 w-5" />}
        />
        <MetricCard
          title="Deposits"
          value={controls.depositsEnabled ? "Enabled" : "Paused"}
          subtitle="Derived from vault and protocol controls"
          icon={<ShieldCheck className="h-5 w-5" />}
        />
        <MetricCard
          title="Strategy Execution"
          value={controls.strategyExecutionEnabled ? "Enabled" : "Restricted"}
          subtitle="Execution depends on risk and guardian capability layers"
          icon={<Zap className="h-5 w-5" />}
        />
      </section>

      <section className="grid gap-6 xl:grid-cols-[1fr,1fr]">
        <div className="card">
          <div className="card-header">Vault Summary</div>

          <div className="card-content grid gap-4 sm:grid-cols-2">
            <SummaryStat
              label="Deposited Assets"
              value={position.depositedAssets}
            />
            <SummaryStat label="Minted Shares" value={position.mintedShares} />
            <SummaryStat
              label="Withdrawable Assets"
              value={position.withdrawableAssets}
            />
            <SummaryStat
              label="Redeemable Shares"
              value={position.redeemableShares}
            />
          </div>
        </div>

        <div className="card">
          <div className="card-header">Vault Metadata</div>

          <div className="card-content space-y-4">
            <MetaRow label="Vault Address" value={vault.address} />
            <MetaRow label="Underlying Asset" value={vault.asset} />
            <MetaRow label="Guardian" value={vault.guardian} />
            <MetaRow label="Registered At" value={vault.registeredAt} />
            <MetaRow label="Status" value={vault.status} />
            <MetaRow label="Decimals" value={String(vault.decimals)} />
          </div>
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-[1fr,1fr]">
        <div className="card">
          <div className="card-header">Deposit & Mint</div>

          <div className="card-content space-y-5">
            <ActionField
              label="Deposit Assets"
              placeholder={`Enter ${vault.asset} amount`}
            />
            <button
              className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50"
              disabled={!controls.depositsEnabled}
            >
              Deposit Assets
            </button>

            <ActionField label="Mint Shares" placeholder="Enter share amount" />
            <button
              className="btn-secondary w-full disabled:cursor-not-allowed disabled:opacity-50"
              disabled={!controls.depositsEnabled}
            >
              Mint Shares
            </button>

            {/* TODO: conectar deposit(...) */}
            {/* TODO: conectar mint(...) */}
            {/* TODO: deshabilitar además por wallet/session si aplica */}
          </div>
        </div>

        <div className="card">
          <div className="card-header">Withdraw & Redeem</div>

          <div className="card-content space-y-5">
            <ActionField
              label="Withdraw Assets"
              placeholder={`Enter ${vault.asset} amount`}
            />
            <button className="btn-primary w-full">Withdraw Assets</button>

            <ActionField
              label="Redeem Shares"
              placeholder="Enter share amount"
            />
            <button className="btn-secondary w-full">Redeem Shares</button>

            {/* TODO: conectar withdraw(...) */}
            {/* TODO: conectar redeem(...) */}
          </div>
        </div>
      </section>

      <section className="card">
        <div className="card-header">Guardian Operations</div>

        <div className="card-content space-y-4">
          <p className="text-sm leading-7 text-text-secondary">
            Guardian-linked execution remains subject to protocol controls,
            vault status and risk monitoring.
          </p>

          <div className="rounded-2xl border border-border bg-gray-50 px-4 py-4">
            <p className="text-sm font-medium text-text-primary">
              Strategy Execution
            </p>
            <p className="mt-1 text-sm leading-6 text-text-secondary">
              Execution is available only when the guardian capability is active
              and execution controls remain enabled.
            </p>
          </div>

          <button
            className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50"
            disabled={
              !capabilities.canExecuteStrategy ||
              !controls.strategyExecutionEnabled
            }
          >
            Execute Strategy
          </button>

          {/* TODO: conectar executeStrategy(...) */}
        </div>
      </section>
    </div>
  );
}
