import { useBondingModel } from "@/hooks/useBondingModel";
import { Metric, Bullet } from "./components";

export default function BondingPage() {
  const {
    assets,
    selectedAsset,
    setSelectedAsset,
    amount,
    setAmount,
    estimatedTokens,
    state,
    position,
    capabilities,
  } = useBondingModel();

  const bondingStatus = state.isFinalized ? "Finalized" : "Active";

  return (
    <div className="space-y-8">
      <section className="rounded-3xl bg-gradient-to-r from-primary to-primary-light px-8 py-10 text-white shadow-card">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-100">
          Bonding Program
        </p>

        <h1 className="mt-4 text-3xl font-semibold leading-tight lg:text-4xl">
          Governance Token Bonding
        </h1>

        <p className="mt-4 max-w-2xl text-sm leading-7 text-blue-50 lg:text-base">
          Acquire governance tokens through the protocol bonding program and
          participate in treasury and governance decisions.
        </p>

        <div className="mt-6 flex items-center gap-3">
          <span
            className={
              state.isFinalized ? "badge-warning" : "badge-success"
            }
          >
            {bondingStatus}
          </span>
        </div>
      </section>

      <section className="grid gap-6 lg:grid-cols-2">
        <div className="card">
          <div className="card-header">Bonding Action</div>

          <div className="card-content space-y-5">
            <div>
              <label className="text-sm text-text-secondary">
                Select Asset
              </label>

              <select
                value={selectedAsset?.address ?? ""}
                onChange={(e) => {
                  const asset = assets.find(
                    (item) => item.address === e.target.value
                  );

                  if (asset) {
                    setSelectedAsset(asset);
                  }
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
              <label className="text-sm text-text-secondary">Amount</label>
              <input
                type="number"
                placeholder="Enter amount"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
              />
            </div>

            <div className="rounded-2xl bg-gray-50 px-4 py-4">
              <p className="text-sm text-text-secondary">
                Estimated Governance Tokens
              </p>
              <p className="mt-2 text-xl font-semibold text-text-primary">
                {estimatedTokens}
              </p>
            </div>

            <button
              className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50"
              disabled={!capabilities.canBuyGovernanceTokens || state.isFinalized}
            >
              Buy Governance Tokens
            </button>

            <p className="text-sm leading-6 text-text-secondary">
              {state.isFinalized
                ? "Bonding has been finalized. No further governance token purchases are allowed."
                : "Bonding is active. Supported assets may be exchanged for governance tokens at the current rate."}
            </p>

            {/* TODO: conectar GenesisBonding.buy(selectedAsset.address, amount) */}
            {/* TODO: bloquear por wallet no conectada */}
            {/* TODO: manejar loading / success / error states del write */}
          </div>
        </div>

        <div className="card">
          <div className="card-header">Bonding Metrics</div>

          <div className="card-content grid gap-4 sm:grid-cols-2">
            <Metric label="Total Distributed" value={state.totalDistributed} />
            <Metric label="Exchange Rate" value={`1 = ${state.rate} GOV`} />
            <Metric label="Program Status" value={bondingStatus} />
            <Metric label="Supported Assets" value={`${assets.length}`} />
          </div>
        </div>
      </section>

      <section className="card">
        <div className="card-header">How Bonding Works</div>

        <div className="card-content space-y-4">
          <Bullet text="Users provide supported assets to the bonding contract." />
          <Bullet text="Governance tokens are issued based on a predefined rate." />
          <Bullet text="Bonding may be finalized by governance decisions." />
          <Bullet text="Once finalized, no further purchases are allowed." />
        </div>
      </section>

      <section className="card">
        <div className="card-header">Your Position</div>

        <div className="card-content grid gap-4 sm:grid-cols-3">
          <Metric label="Governance Tokens" value={position.governanceBalance} />
          <Metric label="Estimated Value" value={position.estimatedValue} />
          <Metric label="Total Purchases" value={String(position.totalPurchases)} />
        </div>
      </section>
    </div>
  );
}