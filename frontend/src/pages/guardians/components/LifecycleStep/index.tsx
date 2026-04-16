type Tone = "success" | "warning" | "danger" | "neutral";

interface LifecycleStepProps {
  title: string;
  description: string;
  tone: Tone;
}

const dotClasses: Record<Tone, string> = {
  success: "bg-green-100 text-green-700",
  warning: "bg-yellow-100 text-yellow-700",
  danger: "bg-red-100 text-red-700",
  neutral: "bg-gray-100 text-gray-700",
};

export function LifecycleStep({ title, description, tone }: LifecycleStepProps) {
  return (
    <div className="flex gap-4">
      <div
        className={`mt-1 flex h-8 w-8 items-center justify-center rounded-full text-sm font-semibold ${dotClasses[tone]}`}
      >
        •
      </div>
      <div>
        <h3 className="text-sm font-semibold text-text-primary">{title}</h3>
        <p className="mt-1 text-sm leading-6 text-text-secondary">{description}</p>
      </div>
    </div>
  );
}
