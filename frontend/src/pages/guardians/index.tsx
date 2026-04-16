import { ArrowRight, ShieldCheck, Users, Wallet } from "lucide-react";
import { useGuardiansModel } from "@/hooks/useGuardiansModel";
import { StatusMetric, LifecycleStep, EscrowMiniCard, OverviewCard } from "./components";

function formatGuardianStatus(status: string) {
  switch (status) {
    case "inactive":
      return "Not Applied";
    case "pending":
      return "Pending Approval";
    case "active":
      return "Active Guardian";
    case "rejected":
      return "Rejected";
    case "resigned":
      return "Resigned";
    case "banned":
      return "Banned";
    default:
      return "Unknown";
  }
}

function getGuardianStatusBadge(status: string) {
  switch (status) {
    case "active":
      return "badge-success";
    case "pending":
      return "badge-warning";
    case "rejected":
    case "banned":
      return "badge-danger";
    default:
      return "rounded-full bg-white/15 px-4 py-2 text-sm font-medium text-white";
  }
}

function getGuardianHelperText(status: string) {
  switch (status) {
    case "pending":
      return "Your application is currently under governance review.";
    case "active":
      return "You already have access to guardian operations.";
    case "rejected":
      return "Your previous application was not approved.";
    case "resigned":
      return "You are currently not active after resignation.";
    case "banned":
      return "Guardian access has been permanently restricted.";
    default:
      return "Connect your wallet to view your guardian eligibility and application status.";
  }
}

export default function GuardiansPage() {
  const { state, metrics, capabilities } = useGuardiansModel();

  return (
    <div className="space-y-8">
      <section className="rounded-3xl bg-gradient-to-r from-primary to-primary-light px-8 py-10 text-white shadow-card">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-100">
          Guardian Network
        </p>

        <h1 className="mt-4 text-3xl font-semibold leading-tight lg:text-4xl">
          Apply to become a protocol guardian and participate in vault deployment
          and strategic execution under governed controls.
        </h1>

        <p className="mt-4 max-w-3xl text-sm leading-7 text-blue-50 lg:text-base">
          Guardians operate within a bonded and reviewable lifecycle designed to
          align execution authority with protocol accountability.
        </p>

        <div className="mt-8 flex flex-wrap gap-3">
          <span className={getGuardianStatusBadge(state.status)}>
            {formatGuardianStatus(state.status)}
          </span>
          <span className="rounded-full bg-white/15 px-4 py-2 text-sm font-medium text-white">
            Min Stake: {state.requiredStake}
          </span>
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-[1.1fr,0.9fr]">
        <div className="card">
          <div className="card-header">My Guardian Status</div>

          <div className="card-content grid gap-4 sm:grid-cols-2">
            <StatusMetric
              label="Current Status"
              value={formatGuardianStatus(state.status)}
            />
            <StatusMetric label="Required Stake" value={state.requiredStake} />
            <StatusMetric label="Bonded Amount" value={state.bondedAmount} />
            <StatusMetric label="Governance State" value={state.proposalState} />
            <StatusMetric
              label="Application Reference"
              value={state.proposalState === "—" ? "—" : "Available"}
            />
            <StatusMetric
              label="Operational Access"
              value={state.canOperate ? "Enabled" : "Disabled"}
            />
          </div>
        </div>

        <div className="card">
          <div className="card-header">Apply as Guardian</div>

          <div className="card-content space-y-5">
            <div className="rounded-2xl border border-border bg-gray-50 px-4 py-4">
              <p className="text-sm font-medium text-text-primary">
                Application Requirements
              </p>

              <ul className="mt-3 space-y-2 text-sm leading-6 text-text-secondary">
                <li>• Bond the required application stake.</li>
                <li>• Submit your guardian application.</li>
                <li>• A governance proposal will be created for approval.</li>
                <li>• Approved guardians may deploy vaults and execute strategies.</li>
              </ul>
            </div>

            <button
              className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50"
              disabled={!capabilities.canApplyAsGuardian}
            >
              Submit Guardian Application
            </button>

            <p className="text-sm leading-6 text-text-secondary">
              {capabilities.canApplyAsGuardian
                ? "You are eligible to submit a guardian application."
                : getGuardianHelperText(state.status)}
            </p>

            {/* TODO: conectar GuardianAdministrator.applyGuardian() */}
            {/* TODO: bloquear por wallet no conectada */}
            {/* TODO: mostrar loading / success / error */}
          </div>
        </div>
      </section>

      <section className="grid gap-6 lg:grid-cols-2">
        <div className="card">
          <div className="card-header">Guardian Lifecycle</div>

          <div className="card-content space-y-4">
            <LifecycleStep
              title="Not Applied"
              description="The user has not submitted a guardian application."
              tone="neutral"
            />
            <LifecycleStep
              title="Application Submitted"
              description="Application stake is bonded and the governance process is initiated."
              tone="warning"
            />
            <LifecycleStep
              title="Pending Governance Review"
              description="The guardian application is waiting for governance approval."
              tone="warning"
            />
            <LifecycleStep
              title="Active Guardian"
              description="Approved guardians gain access to guardian-level protocol operations."
              tone="success"
            />
            <LifecycleStep
              title="Rejected / Resigned / Banned"
              description="The guardian lifecycle has ended or the application was not approved."
              tone="danger"
            />
          </div>
        </div>

        <div className="card">
          <div className="card-header">Bond Escrow</div>

          <div className="card-content space-y-5">
            <div className="rounded-2xl bg-gray-50 px-4 py-4">
              <p className="text-sm text-text-secondary">Escrow Balance</p>
              <p className="mt-2 text-2xl font-semibold text-text-primary">
                {metrics.escrowBalance}
              </p>
              <p className="mt-2 text-sm leading-6 text-text-secondary">
                Guardian applications are backed by bonded collateral held in
                escrow and managed through governed approval, resignation and
                slashing flows.
              </p>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <EscrowMiniCard
                title="Refund Flow"
                description="Rejected applications may be resolved and refunded."
                icon={<Wallet className="h-5 w-5" />}
              />
              <EscrowMiniCard
                title="Operational Integrity"
                description="Bonded collateral supports guardian accountability."
                icon={<ShieldCheck className="h-5 w-5" />}
              />
            </div>
          </div>
        </div>
      </section>

      <section className="card">
        <div className="card-header">Guardian Network Overview</div>

        <div className="card-content grid gap-5 md:grid-cols-3">
          <OverviewCard
            title="Active Guardians"
            value={String(metrics.activeGuardians)}
            subtitle="Currently approved and operational"
            icon={<Users className="h-5 w-5" />}
          />
          <OverviewCard
            title="Pending Applications"
            value={String(metrics.pendingApplications)}
            subtitle="Awaiting governance review"
            icon={<ArrowRight className="h-5 w-5" />}
          />
          <OverviewCard
            title="Escrow Coverage"
            value="Stable"
            subtitle="Application collateral is visible and bonded"
            icon={<ShieldCheck className="h-5 w-5" />}
          />
        </div>
      </section>
    </div>
  );
}