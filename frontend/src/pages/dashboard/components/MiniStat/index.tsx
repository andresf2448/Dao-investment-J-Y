interface MiniStatProps {
  label: string;
  value: string;
}

export function MiniStat({ label, value }: MiniStatProps) {
  return (
    <div className="rounded-2xl border border-border bg-gray-50 px-4 py-4">
      <p className="text-sm text-text-secondary">{label}</p>
      <p className="mt-2 text-xl font-semibold text-text-primary">{value}</p>
    </div>
  );
}
