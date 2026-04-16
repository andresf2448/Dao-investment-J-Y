interface ActivityItemProps {
  title: string;
  subtitle: string;
}

export function ActivityItem({ title, subtitle }: ActivityItemProps) {
  return (
    <div className="rounded-2xl border border-border px-4 py-4">
      <h3 className="text-sm font-semibold text-text-primary">{title}</h3>
      <p className="mt-1 text-sm leading-6 text-text-secondary">{subtitle}</p>
    </div>
  );
}
