interface UpgradeRowProps {
  title: string;
  description: string;
}

export function UpgradeRow({ title, description }: UpgradeRowProps) {
  return (
    <div className="rounded-2xl border border-border px-4 py-4">
      <p className="text-sm font-semibold text-text-primary">{title}</p>
      <p className="mt-1 text-sm leading-6 text-text-secondary">{description}</p>
    </div>
  );
}
