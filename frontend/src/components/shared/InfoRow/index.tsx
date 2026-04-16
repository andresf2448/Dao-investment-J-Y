interface InfoRowProps {
  label: string;
  value: string;
}

export function InfoRow({ label, value }: InfoRowProps) {
  return (
    <div className="flex items-center justify-between rounded-2xl border border-border px-4 py-4">
      <p className="text-sm text-text-secondary">{label}</p>
      <p className="max-w-[60%] truncate text-sm font-medium text-text-primary">
        {value}
      </p>
    </div>
  );
}
