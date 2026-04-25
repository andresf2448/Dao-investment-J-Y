import { Plus, Trash2, Vote } from "lucide-react";
import { useProposalComposerModel } from "@/hooks/useProposalComposerModel";
import { HeroMetric, InfoRow } from "@/components/shared";

export default function CreateProposalPage() {
  const {
    title,
    setTitle,
    description,
    setDescription,
    actions,
    addAction,
    updateAction,
    removeAction,
    votingPower,
    proposalThreshold,
    meetsThreshold,
    delegateAddress,
    setDelegateAddress,
    delegateAddressError,
    canDelegateVotes,
    isDelegatingVotes,
    delegateVotes,
    submitProposal,
    canSubmitProposal,
    isSubmitting,
  } = useProposalComposerModel();

  return (
    <div className="space-y-8">
      <section className="rounded-3xl bg-gradient-to-r from-primary to-primary-light px-8 py-10 text-white shadow-card">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-blue-100">
          Governance Composer
        </p>

        <h1 className="mt-4 text-3xl font-semibold leading-tight lg:text-4xl">
          Create Governance Proposal
        </h1>

        <p className="mt-4 max-w-3xl text-sm leading-7 text-blue-50 lg:text-base">
          Compose protocol changes through structured onchain actions and submit
          them for governance review once the proposal threshold is met.
        </p>

        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          <HeroMetric label="Delegated Voting Power" value={votingPower} />
          <HeroMetric label="Proposal Threshold" value={proposalThreshold} />
          <HeroMetric
            label="Eligibility"
            value={meetsThreshold ? "Eligible" : "Below Threshold"}
          />
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-[1fr,0.9fr]">
        <div className="space-y-6">
          <div className="card">
            <div className="card-header">Proposal Metadata</div>

            <div className="card-content space-y-5">
              <div>
                <label className="text-sm text-text-secondary">Proposal Title</label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Enter proposal title"
                  className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
                />
                {title.trim() !== "" && title.trim().length < 5 ? (
                  <p className="mt-2 text-sm text-danger">
                    Proposal title must have at least 5 characters.
                  </p>
                ) : null}
              </div>

              <div>
                <label className="text-sm text-text-secondary">Description</label>
                <textarea
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Describe the governance change and rationale"
                  rows={7}
                  className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
                />
                {description.trim() !== "" && description.trim().length < 10 ? (
                  <p className="mt-2 text-sm text-danger">
                    Description must have at least 10 characters.
                  </p>
                ) : null}
              </div>
            </div>
          </div>

          <div className="card">
            <div className="card-header flex items-center justify-between">
              <span>Proposal Actions</span>

              <button
                type="button"
                onClick={addAction}
                className="inline-flex items-center gap-2 rounded-lg border border-border px-3 py-2 text-sm font-medium text-text-primary transition hover:bg-gray-50"
              >
                <Plus className="h-4 w-4" />
                Add Action
              </button>
            </div>

            <div className="card-content space-y-5">
              {actions.map((action, index) => (
                <div
                  key={action.id}
                  className="rounded-2xl border border-border bg-gray-50 p-4"
                >
                  <div className="mb-4 flex items-center justify-between">
                    <p className="text-sm font-semibold text-text-primary">
                      Action {index + 1}
                    </p>

                    {actions.length > 1 && (
                      <button
                        type="button"
                        onClick={() => removeAction(action.id)}
                        className="inline-flex items-center gap-2 text-sm font-medium text-danger"
                      >
                        <Trash2 className="h-4 w-4" />
                        Remove
                      </button>
                    )}
                  </div>

                  <div className="grid gap-4">
                    <div>
                      <label className="text-sm text-text-secondary">
                        Target Contract
                      </label>
                      <input
                        type="text"
                        value={action.target}
                        onChange={(e) =>
                          updateAction(action.id, "target", e.target.value)
                        }
                        placeholder="0x..."
                        className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
                      />
                      {action.target.trim() !== "" &&
                      !/^0x[a-fA-F0-9]{40}$/.test(action.target.trim()) ? (
                        <p className="mt-2 text-sm text-danger">
                          Target must be a valid contract address.
                        </p>
                      ) : null}
                    </div>

                    <div>
                      <label className="text-sm text-text-secondary">
                        Execution Value
                      </label>
                      <input
                        type="text"
                        value={action.value}
                        onChange={(e) =>
                          updateAction(action.id, "value", e.target.value)
                        }
                        placeholder="0"
                        className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
                      />
                      {action.value.trim() !== "" &&
                      !/^\d+$/.test(action.value.trim()) ? (
                        <p className="mt-2 text-sm text-danger">
                          Execution value must be a whole number and 0 or greater.
                        </p>
                      ) : null}
                    </div>

                    <div>
                      <label className="text-sm text-text-secondary">
                        Calldata
                      </label>
                      <textarea
                        value={action.calldata}
                        onChange={(e) =>
                          updateAction(action.id, "calldata", e.target.value)
                        }
                        placeholder="0x..."
                        rows={4}
                        className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
                      />
                      {action.calldata.trim() !== "" &&
                      !(
                        action.calldata.trim().startsWith("0x") &&
                        action.calldata.trim().length % 2 === 0 &&
                        /^0x[0-9a-fA-F]*$/.test(action.calldata.trim())
                      ) ? (
                        <p className="mt-2 text-sm text-danger">
                          Calldata must be valid hex bytes starting with 0x.
                        </p>
                      ) : null}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
          <div className="card">
            <div className="card-header">Submission</div>

            <div className="card-content space-y-4">
              <p className="text-sm leading-7 text-text-secondary">
                Proposal submission will package the target contracts, execution
                values, calldata actions and description into a governed
                onchain proposal.
              </p>

              <button
                type="button"
                onClick={submitProposal}
                className="btn-primary w-full disabled:cursor-not-allowed disabled:opacity-50"
                disabled={!canSubmitProposal}
              >
                {isSubmitting ? "Submitting..." : "Submit Proposal"}
              </button>
            </div>
          </div>
        </div>

        <div className="space-y-6">
          <div className="card">
            <div className="card-header">Delegate Voting Power</div>

            <div className="card-content space-y-4">
              <div>
                <label className="text-sm text-text-secondary">
                  Delegate Address
                </label>
                <input
                  type="text"
                  value={delegateAddress}
                  onChange={(event) => setDelegateAddress(event.target.value)}
                  placeholder="0x..."
                  disabled={isDelegatingVotes}
                  className="mt-2 w-full rounded-xl border border-border px-4 py-3 text-sm"
                />
                {delegateAddressError ? (
                  <p className="mt-2 text-sm text-danger">
                    {delegateAddressError}
                  </p>
                ) : null}
              </div>

              <button
                type="button"
                className="btn-secondary inline-flex w-full items-center justify-center gap-2 disabled:cursor-not-allowed disabled:opacity-50"
                disabled={!canDelegateVotes}
                onClick={delegateVotes}
              >
                <Vote className="h-4 w-4" />
                {isDelegatingVotes ? "Delegating..." : "Delegate Votes"}
              </button>
            </div>
          </div>

          <div className="card">
            <div className="card-header">Submission Eligibility</div>

            <div className="card-content space-y-4">
              <InfoRow label="Delegated Voting Power" value={votingPower} />
              <InfoRow label="Threshold" value={proposalThreshold} />
              <InfoRow
                label="Status"
                value={meetsThreshold ? "Eligible" : "Below Threshold"}
              />

              <div
                className={`rounded-2xl px-4 py-4 ${
                  meetsThreshold
                    ? "border border-green-200 bg-green-50"
                    : "border border-yellow-200 bg-yellow-50"
                }`}
              >
                <p
                  className={`text-sm font-medium ${
                    meetsThreshold ? "text-green-800" : "text-yellow-800"
                  }`}
                >
                  {meetsThreshold
                    ? "You meet the proposal threshold."
                    : "You need a minimum voting power to submit proposals."}
                </p>
                <p
                  className={`mt-1 text-sm leading-6 ${
                    meetsThreshold ? "text-green-700" : "text-yellow-700"
                  }`}
                >
                  Proposal submission should remain disabled until the connected
                  wallet satisfies governance requirements.
                </p>
              </div>
            </div>
          </div>

        </div>
      </section>
    </div>
  );
}
