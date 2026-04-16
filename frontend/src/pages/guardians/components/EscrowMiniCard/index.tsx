import { ReactNode } from "react";

interface EscrowMiniCardProps {
  title: string;
  description: string;
  icon: ReactNode;
}

export function EscrowMiniCard({ title, description, icon }: EscrowMiniCardProps) {
  return (
    <div className="rounded-2xl border border-border px-4 py-4">
      <div className="w-fit rounded-xl bg-blue-50 p-2 text-primary">{icon}</div>
      <h3 className="mt-4 text-sm font-semibold text-text-primary">{title}</h3>
      <p className="mt-1 text-sm leading-6 text-text-secondary">{description}</p>
    </div>
  );
}
