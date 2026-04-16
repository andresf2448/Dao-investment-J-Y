interface MiniSummaryCardProps {
  title: string;
  value: string;
  subtitle: string;
}

export function MiniSummaryCard({ title, value, subtitle }: MiniSummaryCardProps) {
  return (
    <div className="rounded-2xl border border-border bg-gray-50 px-5 py-5">
      <p className="text-sm font-medium text-text-secondary">{title}</p>
      <p className="mt-4 text-2xl font-semibold text-text-primary">{value}</p>
      <p className="mt-2 text-sm leading-6 text-text-secondary">{subtitle}</p>
    </div>
  );
}
