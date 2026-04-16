interface MetaRowProps {
  label: string;
  value: string;
}

export function MetaRow({ label, value }: MetaRowProps) {
  return (
    <div className="flex items-center justify-between gap-4 rounded-2xl border border-border px-4 py-4">
      <p className="text-sm text-text-secondary">{label}</p>
      <p className="text-sm font-medium text-text-primary">{value}</p>
    </div>
  );
}
