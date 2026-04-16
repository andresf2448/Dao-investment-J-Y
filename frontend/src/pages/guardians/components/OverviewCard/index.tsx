import { ReactNode } from "react";

interface OverviewCardProps {
  title: string;
  value: string;
  subtitle: string;
  icon: ReactNode;
}

export function OverviewCard({ title, value, subtitle, icon }: OverviewCardProps) {
  return (
    <div className="rounded-2xl border border-border bg-gray-50 px-5 py-5">
      <div className="flex items-center justify-between">
        <p className="text-sm font-medium text-text-secondary">{title}</p>
        <div className="rounded-xl bg-blue-50 p-2 text-primary">{icon}</div>
      </div>
      <p className="mt-4 text-2xl font-semibold text-text-primary">{value}</p>
      <p className="mt-2 text-sm leading-6 text-text-secondary">{subtitle}</p>
    </div>
  );
}
