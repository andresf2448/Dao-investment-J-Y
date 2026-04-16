type Tone = "success" | "warning" | "neutral";

interface DiagnosticCardProps {
  title: string;
  value: string;
  subtitle: string;
  tone: Tone;
}

const toneClasses: Record<Tone, string> = {
  success: "bg-green-100 text-green-700",
  warning: "bg-yellow-100 text-yellow-700",
  neutral: "bg-gray-100 text-gray-700",
};

export function DiagnosticCard({ title, value, subtitle, tone }: DiagnosticCardProps) {
  return (
    <div className="rounded-2xl border border-border bg-gray-50 px-5 py-5">
      <div className="flex items-center justify-between">
        <p className="text-sm font-medium text-text-secondary">{title}</p>
        <span className={`rounded-full px-3 py-1 text-xs font-medium ${toneClasses[tone]}`}>
          {value}
        </span>
      </div>
      <p className="mt-4 text-sm leading-6 text-text-secondary">{subtitle}</p>
    </div>
  );
}
