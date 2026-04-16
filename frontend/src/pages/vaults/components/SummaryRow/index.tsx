type Tone = "success" | "warning" | "neutral";

interface SummaryRowProps {
  title: string;
  description: string;
  status: string;
  tone: Tone;
}

const toneClasses: Record<Tone, string> = {
  success: "bg-green-100 text-green-700",
  warning: "bg-yellow-100 text-yellow-700",
  neutral: "bg-gray-100 text-gray-700",
};

export function SummaryRow({ title, description, status, tone }: SummaryRowProps) {
  return (
    <div className="flex items-start justify-between gap-4 rounded-2xl border border-border px-4 py-4">
      <div>
        <h3 className="text-sm font-semibold text-text-primary">{title}</h3>
        <p className="mt-1 text-sm leading-6 text-text-secondary">{description}</p>
      </div>
      <span className={`whitespace-nowrap rounded-full px-3 py-1 text-xs font-medium ${toneClasses[tone]}`}>
        {status}
      </span>
    </div>
  );
}
