import { Link2, Layers3, Settings, ShieldAlert } from "lucide-react";
import { useOperationsModel } from "@/hooks/useOperationsModel";
import { HeroMetric, MetricCard } from "@/components/shared";
import { OperationRow, WiringCard } from "./components";
import {
  formatInfrastructureState,
  formatOperationStatus,
} from "./formatters";

export default function OperationsPage() {
  const {
    status,
    wiring,
    assetSupport,
    wiringForm,
    actions,
    summary,
    capabilities,
  } =
    useOperationsModel();

  const vaultCreationStatusMessage =
    status.vaultCreation === "paused"
      ? "Vault creation is currently paused at protocol level."
      : undefined;
  const vaultDepositsStatusMessage =
    status.vaultDeposits === "paused"
      ? "Vault deposits are currently paused across vault infrastructure."
      : undefined;

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
            label="Tracked Assets"
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
          value={summary.protocolControlsValue}
          subtitle="Vault creation and deposits are controlled separately on-chain."
          icon={<ShieldAlert className="h-5 w-5" />}
        />
        <MetricCard
          title="Asset Support"
          value={`${status.supportedAssetsCount} tracked`}
          subtitle={`${assetSupport.supportedGenesisTokenCount} genesis tokens configured on-chain.`}
          icon={<Layers3 className="h-5 w-5" />}
        />
        <MetricCard
          title="Infrastructure Wiring"
          value={formatInfrastructureState(status.infrastructureState)}
          subtitle="Core, router, registry and treasury references are resolved from the contracts."
          icon={<Link2 className="h-5 w-5" />}
        />
        <MetricCard
          title="Operations Access"
          value={summary.infrastructureAccessValue}
          subtitle={summary.infrastructureAccessSubtitle}
          icon={<Settings className="h-5 w-5" />}
        />
      </section>

      <section className="grid gap-6 xl:grid-cols-[1fr,1fr]">
        <div className="card">
          <div className="card-header">Protocol Controls</div>

          <div className="card-content space-y-4">
            <OperationRow
              title="Vault Creation Controls"
              description="Pause new vault deployment at protocol level."
              primaryAction="Pause Creation"
              disablePrimary={
                !capabilities.canPauseVaultCreation ||
                status.vaultCreation === "paused"
              }
              statusMessage={vaultCreationStatusMessage}
              onPrimaryAction={actions.pauseVaultCreation}
            />
            <OperationRow
              title="Vault Deposit Controls"
              description="Pause deposits across vault infrastructure."
              primaryAction="Pause Deposits"
              disablePrimary={
                !capabilities.canPauseVaultDeposits ||
                status.vaultDeposits === "paused"
              }
              statusMessage={vaultDepositsStatusMessage}
              onPrimaryAction={actions.pauseVaultDeposits}
            />

            {!capabilities.canPauseVaultCreation &&
            !capabilities.canResumeVaultCreation &&
            !capabilities.canPauseVaultDeposits &&
            !capabilities.canResumeVaultDeposits ? (
              <div className="rounded-2xl border border-yellow-200 bg-yellow-50 px-4 py-4">
                <p className="text-sm font-medium text-yellow-800">
                  Controls Protected
                </p>
                <p className="mt-1 text-sm leading-6 text-yellow-700">
                  Operational buttons stay blocked until the connected wallet has
                  manager or emergency permissions.
                </p>
              </div>
            ) : null}

            <div className="rounded-2xl border border-border bg-yellow-50 px-4 py-4">
              <p className="text-sm font-medium text-yellow-800">
                Responsibility Separation
              </p>
              <p className="mt-1 text-sm leading-6 text-yellow-700">
                Emergency operators and managers do not share the same operational
                actions. Pauses can be triggered here, but reactivations must be
                completed through a governed proposal.
              </p>
            </div>

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
                  value={assetSupport.supportedVaultAsset}
                  onChange={(event) =>
                    assetSupport.setSupportedVaultAsset(event.target.value)
                  }
                  placeholder="Asset address"
                  className="w-full rounded-xl border border-border px-4 py-3 text-sm"
                />
                <button
                  className="btn-primary whitespace-nowrap disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={!assetSupport.canAddSupportedVaultAsset}
                  onClick={actions.addSupportedVaultAsset}
                >
                  Add Asset
                </button>
              </div>
              {assetSupport.supportedVaultAssetError ? (
                <p className="mt-2 text-sm text-danger">
                  {assetSupport.supportedVaultAssetError}
                </p>
              ) : null}
              {assetSupport.assetSupportPermissionMessage ? (
                <p className="mt-2 text-sm text-text-secondary">
                  {assetSupport.assetSupportPermissionMessage}
                </p>
              ) : null}
            </div>

            <div>
              <label className="text-sm text-text-secondary">
                Supported Genesis Token
              </label>
              <div className="mt-2 flex gap-3">
                <input
                  type="text"
                  value={assetSupport.supportedGenesisToken}
                  onChange={(event) =>
                    assetSupport.setSupportedGenesisToken(event.target.value)
                  }
                  placeholder="Token address"
                  className="w-full rounded-xl border border-border px-4 py-3 text-sm"
                />
                <button
                  className="btn-secondary whitespace-nowrap disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={!assetSupport.canUpdateSupportedGenesisTokens}
                  onClick={actions.updateSupportedGenesisTokens}
                >
                  Update Set
                </button>
              </div>
              {assetSupport.supportedGenesisTokenError ? (
                <p className="mt-2 text-sm text-danger">
                  {assetSupport.supportedGenesisTokenError}
                </p>
              ) : null}
              {assetSupport.assetSupportPermissionMessage ? (
                <p className="mt-2 text-sm text-text-secondary">
                  {assetSupport.assetSupportPermissionMessage}
                </p>
              ) : null}
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
            inputValue={wiringForm.factoryRouterInput}
            onInputChange={wiringForm.setFactoryRouterInput}
            actionDisabled={!wiringForm.canSubmitFactoryRouter}
            error={wiringForm.factoryRouterError ?? wiringForm.wiringPermissionMessage}
            onAction={actions.setFactoryRouter}
          />
          <WiringCard
            title="Factory Core Assignment"
            description="Update the core reference consumed by VaultFactory."
            action="Set Core"
            value={wiring.factoryCore}
            inputValue={wiringForm.factoryCoreInput}
            onInputChange={wiringForm.setFactoryCoreInput}
            actionDisabled={!wiringForm.canSubmitFactoryCore}
            error={wiringForm.factoryCoreError ?? wiringForm.wiringPermissionMessage}
            onAction={actions.setFactoryCore}
          />
          <WiringCard
            title="Guardian Administrator"
            description="Update the guardian administrator contract reference."
            action="Set Guardian Administrator"
            value={wiring.guardianAdministrator}
            inputValue={wiringForm.guardianAdministratorInput}
            onInputChange={wiringForm.setGuardianAdministratorInput}
            actionDisabled={!wiringForm.canSubmitGuardianAdministrator}
            error={
              wiringForm.guardianAdministratorError ??
              wiringForm.wiringPermissionMessage
            }
            onAction={actions.setGuardianAdministrator}
          />
          <WiringCard
            title="Vault Registry Reference"
            description="Update the vault registry used by deployment flows."
            action="Set Vault Registry"
            value={wiring.vaultRegistry}
            inputValue={wiringForm.vaultRegistryInput}
            onInputChange={wiringForm.setVaultRegistryInput}
            actionDisabled={!wiringForm.canSubmitVaultRegistry}
            error={wiringForm.vaultRegistryError ?? wiringForm.wiringPermissionMessage}
            onAction={actions.setVaultRegistry}
          />
          <WiringCard
            title="Treasury Core Assignment"
            description="Configure the ProtocolCore reference used by Treasury."
            action="Set Protocol Core"
            value={wiring.treasuryProtocolCore}
            inputValue={wiringForm.treasuryProtocolCoreInput}
            onInputChange={wiringForm.setTreasuryProtocolCoreInput}
            actionDisabled={!wiringForm.canSubmitTreasuryProtocolCore}
            error={
              wiringForm.treasuryProtocolCoreError ??
              wiringForm.wiringPermissionMessage
            }
            onAction={actions.setTreasuryProtocolCore}
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
      </section>
    </div>
  );
}
