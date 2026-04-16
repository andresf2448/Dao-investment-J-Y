import { Link } from "react-router-dom";

interface QuickActionButtonProps {
  label: string;
  disabled: boolean;
  to: string;
}

export function QuickActionButton({ label, disabled, to }: QuickActionButtonProps) {
  if (disabled) {
    return (
      <button
        disabled
        className="cursor-not-allowed rounded-xl border border-white/20 bg-white/10 px-5 py-3 text-sm font-medium text-white/60"
      >
        {label}
      </button>
    );
  }

  return (
    <Link
      to={to}
      className="rounded-xl border border-white/30 bg-white/10 px-5 py-3 text-sm font-medium text-white transition hover:bg-white/20"
    >
      {label}
    </Link>
  );
}
