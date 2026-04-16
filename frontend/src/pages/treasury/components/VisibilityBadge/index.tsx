interface VisibilityBadgeProps {
  value: string;
}

export function VisibilityBadge({ value }: VisibilityBadgeProps) {
  return (
    <span className="rounded-full bg-gray-100 px-3 py-1 text-xs font-medium text-gray-700">
      {value}
    </span>
  );
}
