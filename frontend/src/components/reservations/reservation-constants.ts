import type { ReservationStatus } from "@/types/reservation";

export const RESERVATION_STATUS_OPTIONS: Array<{ value: ReservationStatus; label: string }> = [
  { value: "scheduled", label: "予定" },
  { value: "cancelled", label: "キャンセル" },
  { value: "completed", label: "完了" },
];

export const WEEKDAY_OPTIONS: Array<{ value: number; label: string }> = [
  { value: 0, label: "日" },
  { value: 1, label: "月" },
  { value: 2, label: "火" },
  { value: 3, label: "水" },
  { value: 4, label: "木" },
  { value: 5, label: "金" },
  { value: 6, label: "土" },
];

export function formatReservationTime(startTime: string | null, endTime: string | null): string {
  if (!startTime && !endTime) return "-";
  if (startTime && endTime) return `${startTime} - ${endTime}`;
  return startTime || endTime || "-";
}

export function statusLabel(status: ReservationStatus): string {
  return RESERVATION_STATUS_OPTIONS.find((option) => option.value === status)?.label ?? status;
}
