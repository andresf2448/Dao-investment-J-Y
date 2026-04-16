import { Link } from "react-router-dom";
import { ArrowRight } from "lucide-react";

interface QuickActionProps {
  title: string;
  description: string;
  to: string;
}

export function QuickAction({ title, description, to }: QuickActionProps) {
  return (
    <Link
      to={to}
      className="flex items-center justify-between rounded-2xl border border-border px-4 py-4 text-left transition hover:border-primary/30 hover:bg-blue-50/40"
    >
      <div>
        <h3 className="text-sm font-semibold text-text-primary">{title}</h3>
        <p className="mt-1 text-sm leading-6 text-text-secondary">{description}</p>
      </div>
      <div className="rounded-xl bg-blue-50 p-2 text-primary">
        <ArrowRight className="h-4 w-4" />
      </div>
    </Link>
  );
}
