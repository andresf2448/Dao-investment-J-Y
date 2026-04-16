interface ProposalStatusProps {
  status: string;
}

export function ProposalStatus({ status }: ProposalStatusProps) {
  const className =
    status === "Active"
      ? "badge-success"
      : status === "Queued"
        ? "badge-warning"
        : status === "Executed" || status === "Pending"
          ? "rounded-full bg-gray-100 px-3 py-1 text-xs font-medium text-gray-700"
          : "badge-danger";

  return <span className={className}>{status}</span>;
}
