interface VaultStatusProps {
  status: string;
}

export function VaultStatus({ status }: VaultStatusProps) {
  const className =
    status === "Active"
      ? "badge-success"
      : "rounded-full bg-gray-100 px-3 py-1 text-xs font-medium text-gray-700";

  return <span className={className}>{status}</span>;
}
