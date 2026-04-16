export type Tone = "success" | "warning" | "neutral" | "danger";

export type Status = "active" | "inactive" | "paused" | "pending";

export interface PaginationParams {
  page: number;
  limit: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
}
