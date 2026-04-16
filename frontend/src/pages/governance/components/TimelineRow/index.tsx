interface TimelineRowProps {
  label: string;
  value: string;
}

export function TimelineRow({ label, value }: TimelineRowProps) {
  return (
    <div className="flex gap-4">
      <div className="mt-1 flex h-8 w-8 items-center justify-center rounded-full bg-blue-50 text-sm font-semibold text-primary">
        •
      </div>
      <div className="flex-1 rounded-2xl border border-border px-4 py-4">
        <p className="text-sm font-semibold text-text-primary">{label}</p>
        <p className="mt-1 text-sm leading-6 text-text-secondary">{value}</p>
      </div>
    </div>
  );
}
