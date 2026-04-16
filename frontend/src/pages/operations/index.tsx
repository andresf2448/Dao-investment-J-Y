import { Link2, Layers3, Settings, ShieldAlert } from "lucide-react";
import { useOperationsModel } from "@/hooks/useOperationsModel";

export default function OperationsPage() {
  const { status, wiring, capabilities } = useOperationsModel();

  return (
    <div className="space-y-8">
      <section className="rounded-3xl bg-gradient-to-r from-primary to-primary-light px-8 py-10 text-white shadow-card">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-100">
          Operations Console
        </p>

        <h1 className="mt-4 text-3xl font-semibold leading-tight lg:text-4xl">
          Manage protocol controls, supported assets and infrastructure wiring
          through governed operational workflows.
        </h1>

        <p className="mt-4 max-w-3xl text-sm leading-7 text-blue-50 lg:text-base">
          Operational controls are separated by responsibility layers, including
          emergency pauses, manager-level asset configuration and protocol wiring.
        </p>

        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <HeroMetric
            label="Vault Creation"
            value={formatOperationStatus(status.vaultCreation)}
          />
          <HeroMetric
            label="Vault Deposits"
            value={formatOperationStatus(status.vaultDeposits)}
          />
          <HeroMetric
            label="Supported Assets"
            value={String(status.supportedAssetsCount)}
          />
          <HeroMetric
            label="Infrastructure State"
            value={formatInfrastructureState(status.infrastructureState)}
          />
        </div>
      </section>

      <section className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          title="Protocol Controls"
          value="Live"
          subtitle="Pause and resume capabilities are separated by role."
          icon={<ShieldAlert className="h-5 w-5" />}
        />
        <MetricCard
          title="Asset Support"
          value="Configured"
          subtitle="Supported vault assets and genesis tokens are maintained here."
          icon={<Layers3 className="h-5 w-5" />}
        />
        <MetricCard
          title="Infrastructure Wiring"
          value="Linked"
          subtitle="Core, router, registry and guardian references are configurable."
          icon={<Link2 className="h-5 w-5" />}
        />
        <MetricCard
          title="Operations Access"
          value="Restricted"
          subtitle="Operational actions remain protected by protocol capabilities."
          icon={<Settings className="h-5 w-5" />}
        />
      </section>

      <section className="grid gap-6 xl:grid-cols-[1fr,1fr]">
        <div className="card">
          <div className="card-header">Protocol Controls</div>

          <div className="card-content space-y-4">
            <OperationRow
              title="Vault Creation Controls"
              description="Pause or resume new vault deployment at protocol level."
              primaryAction="Pause Creation"
              secondaryAction="Resume Creation"
              disablePrimary={!capabilities.canPauseVaultCreation}
              disableSecondary={!capabilities.canResumeVaultCreation}
            />
            <OperationRow
              title="Vault Deposit Controls"
              description="Pause or resume deposits across vault infrastructure."
              primaryAction="Pause Deposits"
              secondaryAction="Resume Deposits"
              disablePrimary={!capabilities.canPauseVaultDeposits}
              disableSecondary={!capabilities.canResumeVaultDeposits}
            />

            <div className="rounded-2xl border border-border bg-yellow-50 px-4 py-4">
              <p className="text-sm font-medium text-yellow-800">
                Responsibility Separation
              </p>
              <p className="mt-1 text-sm leading-6 text-yellow-700">
                Emergency operators and managers do not share the same operational
                actions. Pause and resume workflows must stay clearly separated.
              </p>
            </div>

            {/* TODO: conectar pause/unpause desde ProtocolCore */}
          </div>
        </div>

        <div className="card">
          <div className="card-header">Asset Support Configuration</div>

          <div className="card-content space-y-5">
            <div>
              <label className="text-sm text-text-secondary">
                Supported Vault Asset
              </label>
              <div className="mt-2 flex gap-3">
                <input
                  type="text"
                  placeholder="Asset address"
                  className="w-full rounded-xl border border-border px-4 py-3 text-sm"
                />
                <button className="btn-primary whitespace-nowrap">
                  Add Asset
                </button>
              </div>
            </div>

            <div>
              <label className="text-sm text-text-secondary">
                Supported Genesis Token
              </label>
              <div className="mt-2 flex gap-3">
                <input
                  type="text"
                  placeholder="Token address"
                  className="w-full rounded-xl border border-border px-4 py-3 text-sm"
                />
                <button className="btn-secondary whitespace-nowrap">
                  Update Set
                </button>
              </div>
            </div>

            <div className="rounded-2xl bg-gray-50 px-4 py-4">
              <p className="text-sm font-medium text-text-primary">
                Configuration Notes
              </p>
              <p className="mt-1 text-sm leading-6 text-text-secondary">
                Supported vault assets and supported genesis tokens drive bonding,
                treasury categorization and infrastructure constraints.
              </p>
            </div>

            {/* TODO: conectar setSupportedVaultAsset y setSupportedGenesisTokens */}
          </div>
        </div>
      </section>

      <section className="card">
        <div className="card-header">Infrastructure Wiring</div>

        <div className="card-content grid gap-5 lg:grid-cols-2">
          <WiringCard
            title="Factory Router Assignment"
            description="Update the router reference used by VaultFactory."
            action="Set Router"
            value={wiring.factoryRouter}
          />
          <WiringCard
            title="Factory Core Assignment"
            description="Update the core reference consumed by VaultFactory."
            action="Set Core"
            value={wiring.factoryCore}
          />
          <WiringCard
            title="Guardian Administrator"
            description="Update the guardian administrator contract reference."
            action="Set Guardian Administrator"
            value={wiring.guardianAdministrator}
          />
          <WiringCard
            title="Vault Registry Reference"
            description="Update the vault registry used by deployment flows."
            action="Set Vault Registry"
            value={wiring.vaultRegistry}
          />
          <WiringCard
            title="Treasury Core Assignment"
            description="Configure the ProtocolCore reference used by Treasury."
            action="Set Protocol Core"
            value={wiring.treasuryProtocolCore}
          />
        </div>

        <div className="mt-6 rounded-2xl border border-border bg-gray-50 px-4 py-4">
          <p className="text-sm font-medium text-text-primary">
            Wiring Awareness
          </p>
          <p className="mt-1 text-sm leading-6 text-text-secondary">
            Contract references should be surfaced clearly and updated only from
            controlled operational workflows.
          </p>
        </div>

        {/* TODO: conectar wiring actions reales */}
      </section>
    </div>
  );
}

function HeroMetric({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div className="rounded-2xl bg-white/10 px-4 py-4 backdrop-blur">
      <p className="text-sm text-blue-50">{label}</p>
      <p className="mt-2 text-xl font-semibold text-white">{value}</p>
    </div>
  );
}

function MetricCard({
  title,
  value,
  subtitle,
  icon,
}: {
  title: string;
  value: string;
  subtitle: string;
  icon: React.ReactNode;
}) {
  return (
    <div className="card">
      <div className="card-content">
        <div className="flex items-center justify-between">
          <p className="text-sm font-medium text-text-secondary">{title}</p>
          <div className="rounded-xl bg-blue-50 p-2 text-primary">{icon}</div>
        </div>

        <p className="mt-5 text-3xl font-semibold text-text-primary">{value}</p>
        <p className="mt-2 text-sm leading-6 text-text-secondary">{subtitle}</p>
      </div>
    </div>
  );
}

function OperationRow({
  title,
  description,
  primaryAction,
  secondaryAction,
  disablePrimary,
  disableSecondary,
}: {
  title: string;
  description: string;
  primaryAction: string;
  secondaryAction: string;
  disablePrimary: boolean;
  disableSecondary: boolean;
}) {
  return (
    <div className="rounded-2xl border border-border px-4 py-4">
      <h3 className="text-sm font-semibold text-text-primary">{title}</h3>
      <p className="mt-1 text-sm leading-6 text-text-secondary">{description}</p>

      <div className="mt-4 flex flex-wrap gap-3">
        <button
          className="btn-primary disabled:cursor-not-allowed disabled:opacity-50"
          disabled={disablePrimary}
        >
          {primaryAction}
        </button>
        <button
          className="btn-secondary disabled:cursor-not-allowed disabled:opacity-50"
          disabled={disableSecondary}
        >
          {secondaryAction}
        </button>
      </div>
    </div>
  );
}

function WiringCard({
  title,
  description,
  action,
  value,
}: {
  title: string;
  description: string;
  action: string;
  value: string;
}) {
  return (
    <div className="rounded-2xl border border-border px-5 py-5">
      <h3 className="text-sm font-semibold text-text-primary">{title}</h3>
      <p className="mt-1 text-sm leading-6 text-text-secondary">{description}</p>

      <div className="mt-3 rounded-xl bg-gray-50 px-4 py-3 text-sm text-text-secondary">
        {value}
      </div>

      <div className="mt-4 flex gap-3">
        <input
          type="text"
          placeholder="Contract address"
          className="w-full rounded-xl border border-border px-4 py-3 text-sm"
        />
        <button className="btn-primary whitespace-nowrap">{action}</button>
      </div>
    </div>
  );
}

function formatOperationStatus(value: "enabled" | "paused") {
  return value === "enabled" ? "Enabled" : "Paused";
}

function formatInfrastructureState(
  value: "linked" | "partial" | "unconfigured"
) {
  switch (value) {
    case "linked":
      return "Linked";
    case "partial":
      return "Partial";
    case "unconfigured":
      return "Unconfigured";
    default:
      return "Unknown";
  }
}