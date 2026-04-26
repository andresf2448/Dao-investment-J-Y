import { useParams } from "react-router-dom";
import { Clock3, Vote } from "lucide-react";
import { useProposalDetailModel } from "@/hooks/useProposalDetailModel";
import {
  CopyValueButton,
  HeroMetric,
  MetricCard,
  InfoRow,
} from "@/components/shared";
import { TimelineRow } from "../";
import { truncateMiddle } from "@/utils";

export default function ProposalDetailPage() {
  const { proposalId } = useParams();
  const {
    proposal,
    capabilities,
    canVote,
    canQueueProposal,
    canExecuteProposal,
    voteFor,
    voteAgainst,
    abstain,
    queueProposal,
    executeProposal,
    isSubmitting,
  } = useProposalDetailModel(proposalId);

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
          <div className="rounded-2xl bg-white/10 px-4 py-4 backdrop-blur">
            <p className="text-sm text-blue-50">Proposal ID</p>
            <p
              className="mt-2 break-all text-lg font-semibold text-white"
              title={proposal.id}
            >
              {truncateMiddle(proposal.id, 8, 6)}
            </p>
            <div className="mt-3">
              <CopyValueButton
                value={proposal.id}
                label="Copy ID"
                className="border-white/30 bg-white/10 text-white hover:bg-white/20"
              />
            </div>
          </div>
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

      <section className="grid items-start gap-6 xl:grid-cols-[minmax(0,1.15fr)_minmax(0,0.85fr)]">
        <div className="min-w-0 space-y-6">
          <div className="card">
            <div className="card-header">Proposal Metadata</div>

            <div className="card-content space-y-6">
              <div>
                <div className="flex items-center justify-between gap-4">
                  <p className="text-sm font-medium text-text-secondary">
                    Title
                  </p>
                  <CopyValueButton value={proposal.title} label="Copy Title" />
                </div>
                <div className="mt-2 rounded-2xl border border-border bg-gray-50 px-4 py-4">
                  <p className="text-sm font-medium leading-7 text-text-primary">
                    {proposal.title}
                  </p>
                </div>
              </div>

              <div>
                <div className="flex items-center justify-between gap-4">
                  <p className="text-sm font-medium text-text-secondary">
                    Description
                  </p>
                  <CopyValueButton
                    value={proposal.description}
                    label="Copy Description"
                  />
                </div>
                <div className="mt-2 rounded-2xl border border-border bg-gray-50 px-4 py-4">
                  <p className="whitespace-pre-wrap text-sm leading-7 text-text-secondary">
                    {proposal.description}
                  </p>
                </div>
              </div>
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
                    <div>
                      <div className="flex items-center justify-between gap-2">
                        <p className="text-sm text-text-secondary">Target</p>
                        <CopyValueButton value={action.target} label="Copy" />
                      </div>
                      <div className="mt-1 rounded-lg border border-border bg-white px-3 py-2">
                        <p className="truncate text-sm font-medium text-text-primary">
                          {action.target}
                        </p>
                      </div>
                    </div>

                    <div>
                      <div className="flex items-center justify-between gap-2">
                        <p className="text-sm text-text-secondary">Value</p>
                      </div>
                      <div className="mt-1 rounded-lg border border-border bg-white px-3 py-2">
                        <p className="text-sm font-medium text-text-primary">
                          {action.value}
                        </p>
                      </div>
                    </div>

                    <div>
                      <div className="flex items-center justify-between gap-2">
                        <p className="text-sm text-text-secondary">Calldata</p>
                        <CopyValueButton value={action.calldata} label="Copy" />
                      </div>
                      <div className="mt-1 rounded-lg border border-border bg-white px-3 py-2">
                        <p className="truncate text-sm font-mono text-text-primary">
                          {action.calldata}
                        </p>
                      </div>
                    </div>
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

          <div className="card">
            <div className="card-header">Delegated Votes Ready</div>

            <div className="card-content">
              <div className="rounded-2xl border border-border bg-gray-50 px-4 py-5">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <p className="text-sm font-medium text-text-secondary">
                      Voting power delegated to the connected wallet
                    </p>
                    <p className="mt-3 text-3xl font-semibold leading-tight text-text-primary">
                      {proposal.delegatedVotes}
                    </p>
                  </div>

                  <div className="rounded-xl bg-blue-50 p-2 text-primary">
                    <Vote className="h-5 w-5" />
                  </div>
                </div>

                <p className="mt-4 text-sm leading-6 text-text-secondary">
                  These are the governance votes currently ready to be cast from
                  the wallet connected to this session.
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="min-w-0 space-y-6">
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
              <button
                type="button"
                className="btn-secondary w-full disabled:cursor-not-allowed disabled:opacity-50"
                onClick={voteFor}
                disabled={!canVote}
              >
                Vote For
              </button>

              <button
                type="button"
                className="btn-secondary w-full disabled:cursor-not-allowed disabled:opacity-50"
                onClick={voteAgainst}
                disabled={!canVote}
              >
                Vote Against
              </button>

              <button
                type="button"
                className="btn-secondary w-full disabled:cursor-not-allowed disabled:opacity-50"
                onClick={abstain}
                disabled={!canVote}
              >
                Abstain
              </button>

              <button
                type="button"
                className="btn-warning w-full disabled:cursor-not-allowed disabled:opacity-50"
                onClick={queueProposal}
                disabled={!canQueueProposal}
              >
                Queue Proposal
              </button>

              <button
                type="button"
                className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50"
                onClick={executeProposal}
                disabled={!canExecuteProposal}
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