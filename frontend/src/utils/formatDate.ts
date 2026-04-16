export function formatDate(
  timestamp: string | number | Date,
  options: Intl.DateTimeFormatOptions = {
    year: "numeric",
    month: "short",
    day: "numeric",
  }
): string {
  const date = new Date(timestamp);
  if (isNaN(date.getTime())) return "—";
  return date.toLocaleDateString("en-US", options);
}

export function formatDateTime(timestamp: string | number | Date): string {
  return formatDate(timestamp, {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatRelativeTime(timestamp: string | number | Date): string {
  const date = new Date(timestamp);
  if (isNaN(date.getTime())) return "—";

  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffSecs = Math.floor(diffMs / 1000);
  const diffMins = Math.floor(diffSecs / 60);
  const diffHours = Math.floor(diffMins / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffSecs < 60) return "Just now";
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;

  return formatDate(timestamp);
}

export function parseTimestamp(timestamp: string | number): Date {
  const num = typeof timestamp === "string" ? parseInt(timestamp) : timestamp;
  return new Date(num * 1000);
}
