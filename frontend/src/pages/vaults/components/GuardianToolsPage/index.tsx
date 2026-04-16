import { ShieldCheck, Sparkles, Vault } from "lucide-react";
import { useGuardianVaultToolsModel } from "@/hooks/useGuardianVaultToolsModel";
import { HeroMetric, InfoRow, NoteRow } from "@/components/shared";

export default function GuardianToolsPage() {
  const {
    assets,
    selectedAsset,
    setSelectedAsset,
    vaultName,
    setVaultName,
    vaultSymbol,
    setVaultSymbol,
    predictedAddress,
    pairExists,
    canCreateVault,
    capabilities,
  } = useGuardianVaultToolsModel();

  return (
    <div className="space-y-8">
      <section className="rounded-3xl bg-gradient-to-r from-primary to-primary-light px-8 py-10 text-white shadow-card">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-100">
          Guardian Vault Tools
        </p>

        <h1 className="mt-4 text-3xl font-semibold leading-tight lg:text-4xl">
          Deploy vault infrastructure and validate guardian asset pairs before
          execution.
        </h1>

        <p className="mt-4 max-w-3xl text-sm leading-7 text-blue-50 lg:text-base">
          Guardian vault tooling should remain gated by active guardian status,
          supported asset controls and protocol deployment rules.
        </p>

        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <HeroMetric
            label="Guardian Access"
            value={capabilities.canAccessGuardianOperations ? "Enabled" : "Restricted"}
          />
          <HeroMetric
            label="Create Vault"
            value={capabilities.canCreateVault ? "Available" : "Restricted"}
          />
          <HeroMetric
            label="Selected Asset"
            value={selectedAsset?.symbol ?? "—"}
          />
          <HeroMetric
            label="Pair Availability"
            value={pairExists ? "Already Exists" : "Available"}
          />
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-[1fr,0.9fr]">
        <div className="card">
          <div className="card-header">Create New Vault</div>

          <div className="card-content space-y-5">
            <div>
              <label className="text-sm text-text-secondary">Asset</label>
              <select
                value={selectedAsset?.address ?? ""}
                onChange={(e) => {
                  const asset = assets.find((item) => item.address === e.target.value);
                  if (asset) setSelectedAsset(asset);
                }}
                className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
              >
                {assets.map((asset) => (
                  <option key={asset.address} value={asset.address}>
                    {asset.symbol}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="text-sm text-text-secondary">Vault Name</label>
              <input
                type="text"
                value={vaultName}
                onChange={(e) => setVaultName(e.target.value)}
                placeholder="Enter vault name"
                className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
              />
            </div>

            <div>
              <label className="text-sm text-text-secondary">Vault Symbol</label>
              <input
                type="text"
                value={vaultSymbol}
                onChange={(e) => setVaultSymbol(e.target.value)}
                placeholder="Enter vault symbol"
                className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
              />
            </div>

            <button
              className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50"
              disabled={!canCreateVault}
            >
              Create Vault
            </button>

            {/* TODO: conectar VaultFactory.createVault(asset, name, symbol) */}
            {/* TODO: mostrar tx pending / success / error */}
          </div>
        </div>

        <div className="space-y-6">
          <div className="card">
            <div className="card-header">Predicted Address</div>

            <div className="card-content space-y-4">
              <InfoRow label="Predicted Vault" value={predictedAddress} />
              <InfoRow
                label="Asset"
                value={selectedAsset?.symbol ?? "—"}
              />
              <InfoRow
                label="Pair Exists"
                value={pairExists ? "Yes" : "No"}
              />

              <div
                className={`rounded-2xl px-4 py-4 ${
                  pairExists
                    ? "border border-yellow-200 bg-yellow-50"
                    : "border border-green-200 bg-green-50"
                }`}
              >
                <p
                  className={`text-sm font-medium ${
                    pairExists ? "text-yellow-800" : "text-green-800"
                  }`}
                >
                  {pairExists
                    ? "A guardian vault already exists for this pair."
                    : "This guardian and asset pair is available."}
                </p>
                <p
                  className={`mt-1 text-sm leading-6 ${
                    pairExists ? "text-yellow-700" : "text-green-700"
                  }`}
                >
                  Deployment should be blocked when a guardian-linked vault already
                  exists for the selected asset.
                </p>
              </div>
            </div>
          </div>

          <div className="card">
            <div className="card-header">Guardian Notes</div>

            <div className="card-content space-y-4">
              <NoteRow
                icon={<ShieldCheck className="h-5 w-5" />}
                title="Access Requirements"
                description="Only active guardians should access deployment tooling."
              />
              <NoteRow
                icon={<Vault className="h-5 w-5" />}
                title="Deployment Rules"
                description="Vault creation depends on supported assets and protocol pause state."
              />
              <NoteRow
                icon={<Sparkles className="h-5 w-5" />}
                title="Execution Readiness"
                description="Deployment is only the first step before guardian strategy execution."
              />
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}