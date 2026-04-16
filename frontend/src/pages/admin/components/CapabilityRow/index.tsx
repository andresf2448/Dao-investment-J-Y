type Tone = "success" | "warning" | "neutral";

interface CapabilityRowProps {
  title: string;
  status: string;
  tone: Tone;
}

const toneClasses: Record<Tone, string> = {
  success: "bg-green-100 text-green-700",
  warning: "bg-yellow-100 text-yellow-700",
  neutral: "bg-gray-100 text-gray-700",
};

export function CapabilityRow({ title, status, tone }: CapabilityRowProps) {
  return (
    <div className="flex items-center justify-between rounded-2xl border border-border px-4 py-4">
      <p className="text-sm font-medium text-text-primary">{title}</p>
      <span className={`rounded-full px-3 py-1 text-xs font-medium ${toneClasses[tone]}`}>
        {status}
      </span>
    </div>
  );
}
