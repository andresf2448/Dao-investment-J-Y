type Tone = "success" | "warning" | "neutral" | "danger";

interface StatusBadgeProps {
  value: string;
  tone?: Tone;
}

const toneClasses: Record<Tone, string> = {
  success: "bg-green-100 text-green-700",
  warning: "bg-yellow-100 text-yellow-700",
  neutral: "bg-gray-100 text-gray-700",
  danger: "bg-red-100 text-red-700",
};

export function StatusBadge({ value, tone = "neutral" }: StatusBadgeProps) {
  return (
    <span className={`rounded-full px-3 py-1 text-xs font-medium ${toneClasses[tone]}`}>
      {value}
    </span>
  );
}
