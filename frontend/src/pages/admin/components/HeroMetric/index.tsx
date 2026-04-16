interface HeroMetricProps {
  label: string;
  value: string;
}

export function HeroMetric({ label, value }: HeroMetricProps) {
  return (
    <div className="rounded-2xl bg-white/10 px-4 py-4 backdrop-blur">
      <p className="text-sm text-blue-50">{label}</p>
      <p className="mt-2 text-xl font-semibold text-white">{value}</p>
    </div>
  );
}
