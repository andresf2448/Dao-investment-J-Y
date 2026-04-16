interface CategoryBadgeProps {
  category: string;
}

export function CategoryBadge({ category }: CategoryBadgeProps) {
  const className =
    category === "DAO Asset"
      ? "badge-success"
      : "rounded-full bg-yellow-100 px-3 py-1 text-xs font-medium text-yellow-700";

  return <span className={className}>{category}</span>;
}
