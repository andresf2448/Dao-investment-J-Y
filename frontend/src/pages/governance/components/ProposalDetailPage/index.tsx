import { useParams } from "react-router-dom";
import { Clock3, Vote } from "lucide-react";
import { useProposalDetailModel } from "@/hooks/useProposalDetailModel";
import { HeroMetric, MetricCard, InfoRow } from "@/components/shared";
import { TimelineRow } from "../";

export default function ProposalDetailPage() {
  const { proposalId } = useParams();
  const { proposal, capabilities } = useProposalDetailModel(proposalId);

  return (
    <div className="space-y-8">
      <section className="rounded-3xl bg-gradient-to-r from-primary to-primary-light px-8 py-10 text-white shadow-card">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-100">
          Proposal Detail
        </p>

        <h1 className="mt-4 text-3xl font-semibold leading-tight lg:text-4xl">
          {proposal.title}
        </h1>

        <p className="mt-4 max-w-3xl text-sm leading-7 text-blue-50 lg:text-base">
          Review the proposal status, vote breakdown, execution timeline and
          structured onchain actions associated with this governance item.
        </p>

        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <HeroMetric label="Proposal ID" value={proposal.id} />
          <HeroMetric label="Status" value={proposal.status} />
          <HeroMetric label="Proposer" value={proposal.proposer} />
          <HeroMetric label="Execution ETA" value={proposal.executionEta} />
        </div>
      </section>

      <section className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          title="For Votes"
          value={proposal.votes.forVotes}
          subtitle="Supportive governance voting power"
          icon={<Vote className="h-5 w-5" />}
        />
        <MetricCard
          title="Against Votes"
          value={proposal.votes.againstVotes}
          subtitle="Opposing governance voting power"
          icon={<Vote className="h-5 w-5" />}
        />
        <MetricCard
          title="Abstain Votes"
          value={proposal.votes.abstainVotes}
          subtitle="Neutral governance voting power"
          icon={<Vote className="h-5 w-5" />}
        />
        <MetricCard
          title="Execution State"
          value={proposal.status}
          subtitle="Current lifecycle and execution posture"
          icon={<Clock3 className="h-5 w-5" />}
        />
      </section>

      <section className="grid gap-6 xl:grid-cols-[1fr,0.9fr]">
        <div className="space-y-6">
          <div className="card">
            <div className="card-header">Proposal Description</div>

            <div className="card-content">
              <p className="text-sm leading-7 text-text-secondary">
                {proposal.description}
              </p>
            </div>
          </div>

          <div className="card">
            <div className="card-header">Execution Actions</div>

            <div className="card-content space-y-4">
              {proposal.actions.map((action, index) => (
                <div
                  key={`${action.target}-${index}`}
                  className="rounded-2xl border border-border bg-gray-50 p-4"
                >
                  <p className="text-sm font-semibold text-text-primary">
                    Action {index + 1}
                  </p>

                  <div className="mt-3 space-y-2">
                    <InfoRow label="Target" value={action.target} />
                    <InfoRow label="Value" value={action.value} />
                    <InfoRow label="Calldata" value={action.calldata} />
                  </div>
                </div>
              ))}

              {proposal.actions.length === 0 && (
                <p className="text-sm text-text-secondary">
                  No actions available for this proposal.
                </p>
              )}
            </div>
          </div>
        </div>

        <div className="space-y-6">
          <div className="card">
            <div className="card-header">Proposal Timeline</div>

            <div className="card-content space-y-4">
              {proposal.timeline.map((item) => (
                <TimelineRow
                  key={item.label}
                  label={item.label}
                  value={item.value}
                />
              ))}
            </div>
          </div>

          <div className="card">
            <div className="card-header">Proposal Actions</div>

            <div className="card-content space-y-4">
              <button className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50">
                Vote For
              </button>

              <button className="btn-secondary w-full disabled:cursor-not-allowed disabled:opacity-50">
                Vote Against
              </button>

              <button className="btn-secondary w-full disabled:cursor-not-allowed disabled:opacity-50">
                Abstain
              </button>

              <button
                className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50"
                disabled={proposal.status !== "Queued"}
              >
                Execute Proposal
              </button>

              <div className="rounded-2xl border border-border bg-gray-50 px-4 py-4">
                <p className="text-sm font-medium text-text-primary">
                  Interaction Notes
                </p>
                <p className="mt-1 text-sm leading-6 text-text-secondary">
                  Voting, queueing and execution should be enabled only when the
                  proposal state and user capability model allow the action.
                </p>
                <p className="mt-3 text-sm text-text-secondary">
                  Admin console access:{" "}
                  <span className="font-medium text-text-primary">
                    {capabilities.canAccessAdminConsole
                      ? "Enabled"
                      : "Restricted"}
                  </span>
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
