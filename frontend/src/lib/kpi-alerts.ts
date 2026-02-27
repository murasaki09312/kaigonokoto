export type KpiAlertLevel = "normal" | "warning" | "critical";
export type ShuttleCardMode = "pickup" | "dropoff";
export type DashboardKpiCardId = "scheduled" | "attendance-pending" | "shuttle-pending" | "record-pending";
type KpiAlertKey = "attendance" | "shuttle_pickup" | "shuttle_dropoff" | "record";

type KpiDeadlineRule = {
  warningAt: string;
  criticalAt: string;
};

export const KPI_DEADLINE_RULES: Record<KpiAlertKey, KpiDeadlineRule> = {
  attendance: {
    warningAt: "10:30",
    criticalAt: "11:00",
  },
  shuttle_pickup: {
    warningAt: "09:30",
    criticalAt: "10:00",
  },
  shuttle_dropoff: {
    warningAt: "16:30",
    criticalAt: "17:00",
  },
  record: {
    warningAt: "16:30",
    criticalAt: "17:00",
  },
};

const MORNING_CARD_ORDER: DashboardKpiCardId[] = [
  "scheduled",
  "attendance-pending",
  "shuttle-pending",
  "record-pending",
];

const AFTERNOON_CARD_ORDER: DashboardKpiCardId[] = [
  "scheduled",
  "record-pending",
  "shuttle-pending",
  "attendance-pending",
];

const ALERT_CLASSNAME_MAP: Record<KpiAlertLevel, string> = {
  normal: "",
  warning: "border-yellow-400 bg-yellow-50",
  critical: "border-red-500 bg-red-50 animate-pulse",
};

function parseTimeToMinutes(value: string): number {
  const [hoursString, minutesString] = value.split(":");
  const hours = Number(hoursString);
  const minutes = Number(minutesString);
  return hours * 60 + minutes;
}

function minutesFromDate(now: Date): number {
  return now.getHours() * 60 + now.getMinutes();
}

export function isAfternoon(now: Date): boolean {
  return now.getHours() >= 12;
}

export function resolveShuttleCardMode(now: Date): ShuttleCardMode {
  return isAfternoon(now) ? "dropoff" : "pickup";
}

export function resolveKpiAlertLevel(params: {
  now: Date;
  pendingCount: number;
  deadlineRule: KpiDeadlineRule;
}): KpiAlertLevel {
  if (params.pendingCount <= 0) return "normal";

  const currentMinutes = minutesFromDate(params.now);
  const warningMinutes = parseTimeToMinutes(params.deadlineRule.warningAt);
  const criticalMinutes = parseTimeToMinutes(params.deadlineRule.criticalAt);

  if (currentMinutes >= criticalMinutes) return "critical";
  if (currentMinutes >= warningMinutes) return "warning";
  return "normal";
}

export function resolveDashboardCardAlertLevels(params: {
  now: Date;
  shuttleMode: ShuttleCardMode;
  pendingAttendance: number;
  pendingShuttle: number;
  pendingRecord: number;
}): Record<DashboardKpiCardId, KpiAlertLevel> {
  const shuttleDeadlineRule = params.shuttleMode === "dropoff"
    ? KPI_DEADLINE_RULES.shuttle_dropoff
    : KPI_DEADLINE_RULES.shuttle_pickup;

  return {
    scheduled: "normal",
    "attendance-pending": resolveKpiAlertLevel({
      now: params.now,
      pendingCount: params.pendingAttendance,
      deadlineRule: KPI_DEADLINE_RULES.attendance,
    }),
    "shuttle-pending": resolveKpiAlertLevel({
      now: params.now,
      pendingCount: params.pendingShuttle,
      deadlineRule: shuttleDeadlineRule,
    }),
    "record-pending": resolveKpiAlertLevel({
      now: params.now,
      pendingCount: params.pendingRecord,
      deadlineRule: KPI_DEADLINE_RULES.record,
    }),
  };
}

export function getKpiCardAlertClassName(level: KpiAlertLevel): string {
  return ALERT_CLASSNAME_MAP[level];
}

export function sortDashboardKpiCards<T extends { id: DashboardKpiCardId }>(cards: T[], now: Date): T[] {
  const order = isAfternoon(now) ? AFTERNOON_CARD_ORDER : MORNING_CARD_ORDER;
  const priority = new Map(order.map((id, index) => [id, index]));

  return [...cards].sort((left, right) => {
    const leftPriority = priority.get(left.id) ?? Number.MAX_SAFE_INTEGER;
    const rightPriority = priority.get(right.id) ?? Number.MAX_SAFE_INTEGER;
    return leftPriority - rightPriority;
  });
}
