import type { ContractServices } from "@/types/contract";

export const WEEKDAY_OPTIONS = [
  { value: 0, label: "日" },
  { value: 1, label: "月" },
  { value: 2, label: "火" },
  { value: 3, label: "水" },
  { value: 4, label: "木" },
  { value: 5, label: "金" },
  { value: 6, label: "土" },
] as const;

export const SERVICE_OPTIONS = [
  { key: "meal", label: "食事" },
  { key: "bath", label: "入浴" },
  { key: "rehabilitation", label: "機能訓練" },
  { key: "recreation", label: "レクリエーション" },
  { key: "nursing", label: "看護対応" },
  { key: "outing", label: "外出支援" },
] as const;

export function formatWeekdays(weekdays: number[]): string {
  if (weekdays.length === 0) return "-";

  const labels = WEEKDAY_OPTIONS
    .filter((option) => weekdays.includes(option.value))
    .map((option) => option.label);

  return labels.length > 0 ? labels.join("・") : "-";
}

export function formatServices(services: ContractServices): string {
  const enabledServices = SERVICE_OPTIONS
    .filter((option) => Boolean(services[option.key]))
    .map((option) => option.label);

  return enabledServices.length > 0 ? enabledServices.join(" / ") : "なし";
}
