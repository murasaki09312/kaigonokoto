import { describe, expect, it } from "vitest";
import {
  resolveDashboardCardAlertLevels,
  resolveKpiAlertLevel,
  resolveShuttleCardMode,
  sortDashboardKpiCards,
  type DashboardKpiCardId,
} from "./kpi-alerts";

describe("kpi-alerts", () => {
  it("returns warning and critical at configured attendance thresholds", () => {
    const warning = resolveKpiAlertLevel({
      now: new Date(2026, 1, 27, 10, 30),
      pendingCount: 1,
      deadlineRule: { warningAt: "10:30", criticalAt: "11:00" },
    });
    const critical = resolveKpiAlertLevel({
      now: new Date(2026, 1, 27, 11, 0),
      pendingCount: 1,
      deadlineRule: { warningAt: "10:30", criticalAt: "11:00" },
    });

    expect(warning).toBe("warning");
    expect(critical).toBe("critical");
  });

  it("keeps alert level normal when pending count is zero", () => {
    const level = resolveKpiAlertLevel({
      now: new Date(2026, 1, 27, 18, 0),
      pendingCount: 0,
      deadlineRule: { warningAt: "10:30", criticalAt: "11:00" },
    });

    expect(level).toBe("normal");
  });

  it("switches shuttle mode to dropoff in afternoon", () => {
    expect(resolveShuttleCardMode(new Date(2026, 1, 27, 11, 59))).toBe("pickup");
    expect(resolveShuttleCardMode(new Date(2026, 1, 27, 12, 0))).toBe("dropoff");
  });

  it("sorts KPI cards based on morning/afternoon priority", () => {
    const cards: Array<{ id: DashboardKpiCardId; label: string }> = [
      { id: "record-pending", label: "record" },
      { id: "scheduled", label: "scheduled" },
      { id: "shuttle-pending", label: "shuttle" },
      { id: "attendance-pending", label: "attendance" },
    ];

    const morning = sortDashboardKpiCards(cards, new Date(2026, 1, 27, 9, 0)).map((card) => card.id);
    const afternoon = sortDashboardKpiCards(cards, new Date(2026, 1, 27, 13, 0)).map((card) => card.id);

    expect(morning).toEqual(["scheduled", "attendance-pending", "shuttle-pending", "record-pending"]);
    expect(afternoon).toEqual(["scheduled", "record-pending", "shuttle-pending", "attendance-pending"]);
  });

  it("resolves dashboard levels from each pending counter", () => {
    const levels = resolveDashboardCardAlertLevels({
      now: new Date(2026, 1, 27, 17, 5),
      pendingAttendance: 1,
      pendingShuttle: 1,
      pendingRecord: 1,
    });

    expect(levels["attendance-pending"]).toBe("critical");
    expect(levels["shuttle-pending"]).toBe("critical");
    expect(levels["record-pending"]).toBe("critical");
  });
});
