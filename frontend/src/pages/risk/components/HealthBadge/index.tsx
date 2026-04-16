interface HealthBadgeProps {
  value: string;
}

export function HealthBadge({ value }: HealthBadgeProps) {
  const className =
    value === "Healthy"
      ? "badge-success"
      : value === "Monitoring"
        ? "badge-warning"
        : "badge-danger";

  return <span className={className}>{value}</span>;
}
