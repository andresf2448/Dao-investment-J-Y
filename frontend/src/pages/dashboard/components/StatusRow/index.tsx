type Tone = "success" | "warning" | "danger" | "neutral";

interface StatusRowProps {
  label: string;
  value: string;
  tone: Tone;
}

const toneClasses: Record<Tone, string> = {
  success: "bg-green-100 text-green-700",
  warning: "bg-yellow-100 text-yellow-700",
  danger: "bg-red-100 text-red-700",
  neutral: "bg-white/20 text-white",
};

export function StatusRow({ label, value, tone }: StatusRowProps) {
  return (
    <div className="flex items-center justify-between rounded-2xl bg-white/10 px-4 py-3">
      <p className="text-sm text-blue-50">{label}</p>
      <span className={`rounded-full px-3 py-1 text-xs font-medium ${toneClasses[tone]}`}>
        {value}
      </span>
    </div>
  );
}
