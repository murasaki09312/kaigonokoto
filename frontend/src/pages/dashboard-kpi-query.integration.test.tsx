// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter, Route, Routes, useLocation } from "react-router-dom";
import { DashboardPage } from "@/pages/dashboard-page";
import { TodayBoardPage } from "@/pages/today-board-page";
import { ShuttleBoardPage } from "@/pages/shuttle-board-page";
import { CareRecordsPage } from "@/pages/care-records-page";
import type { CareRecord, TodayBoardResponse } from "@/types/today-board";
import type { Reservation } from "@/types/reservation";
import type { ShuttleBoardResponse, ShuttleDirection, ShuttleLegStatus } from "@/types/shuttle";
import * as api from "@/lib/api";

const mockAuthState = vi.hoisted(() => ({
  permissions: ["today_board:read", "shuttles:read", "attendances:manage", "care_records:manage"] as string[],
}));

vi.mock("@/providers/auth-provider", () => ({
  useAuth: () => ({
    permissions: mockAuthState.permissions,
  }),
}));

vi.mock("@/lib/api", () => ({
  getTodayBoard: vi.fn(),
  getShuttleBoard: vi.fn(),
  upsertAttendance: vi.fn(),
  upsertCareRecord: vi.fn(),
  upsertShuttleLeg: vi.fn(),
}));

function createReservation(id: number, clientName: string): Reservation {
  return {
    id,
    tenant_id: 1,
    client_id: id,
    client_name: clientName,
    service_date: "2026-02-27",
    start_time: "09:00",
    end_time: "16:00",
    status: "scheduled",
    notes: null,
    created_at: "2026-02-27T00:00:00Z",
    updated_at: "2026-02-27T00:00:00Z",
  };
}

function createCareRecord(reservationId: number): CareRecord {
  return {
    id: reservationId,
    tenant_id: 1,
    reservation_id: reservationId,
    recorded_by_user_id: 1,
    body_temperature: 36.5,
    systolic_bp: 120,
    diastolic_bp: 80,
    pulse: 70,
    spo2: 98,
    care_note: "記録済み",
    handoff_note: "申し送りあり",
    created_at: "2026-02-27T00:00:00Z",
    updated_at: "2026-02-27T00:00:00Z",
  };
}

function createTodayBoardResponse(): TodayBoardResponse {
  const reservationA = createReservation(1, "利用者A");
  const reservationB = createReservation(2, "利用者B");

  return {
    items: [
      {
        reservation: reservationA,
        attendance: null,
        care_record: null,
        line_notification: null,
        line_notification_available: false,
        line_linked_family_count: 0,
        line_enabled_family_count: 0,
      },
      {
        reservation: reservationB,
        attendance: {
          id: 2,
          tenant_id: 1,
          reservation_id: 2,
          status: "present",
          absence_reason: null,
          contacted_at: null,
          note: null,
          created_at: "2026-02-27T00:00:00Z",
          updated_at: "2026-02-27T00:00:00Z",
        },
        care_record: createCareRecord(2),
        line_notification: null,
        line_notification_available: false,
        line_linked_family_count: 0,
        line_enabled_family_count: 0,
      },
    ],
    meta: {
      date: "2026-02-27",
      total: 2,
      attendance_counts: {
        pending: 1,
        present: 1,
        absent: 0,
        cancelled: 0,
      },
      care_record_completed: 1,
      care_record_pending: 1,
    },
  };
}

function createShuttleResponse(): ShuttleBoardResponse {
  const pendingReservation = createReservation(1, "送迎A");
  const boardedReservation = createReservation(2, "送迎B");

  const leg = (status: ShuttleLegStatus, direction: ShuttleDirection) => ({
    id: 1,
    tenant_id: 1,
    shuttle_operation_id: 1,
    direction,
    status,
    planned_at: null,
    actual_at: null,
    handled_by_user_id: null,
    handled_by_user_name: null,
    note: null,
    created_at: "2026-02-27T00:00:00Z",
    updated_at: "2026-02-27T00:00:00Z",
  });

  return {
    items: [
      {
        reservation: pendingReservation,
        shuttle_operation: {
          id: 1,
          tenant_id: 1,
          reservation_id: 1,
          client_id: 1,
          service_date: "2026-02-27",
          requires_pickup: true,
          requires_dropoff: true,
          pickup_leg: leg("pending", "pickup"),
          dropoff_leg: leg("pending", "dropoff"),
          created_at: "2026-02-27T00:00:00Z",
          updated_at: "2026-02-27T00:00:00Z",
        },
      },
      {
        reservation: boardedReservation,
        shuttle_operation: {
          id: 2,
          tenant_id: 1,
          reservation_id: 2,
          client_id: 2,
          service_date: "2026-02-27",
          requires_pickup: true,
          requires_dropoff: true,
          pickup_leg: leg("boarded", "pickup"),
          dropoff_leg: leg("pending", "dropoff"),
          created_at: "2026-02-27T00:00:00Z",
          updated_at: "2026-02-27T00:00:00Z",
        },
      },
    ],
    meta: {
      date: "2026-02-27",
      total: 2,
      pickup_counts: {
        pending: 1,
        boarded: 1,
        alighted: 0,
        cancelled: 0,
      },
      dropoff_counts: {
        pending: 2,
        boarded: 0,
        alighted: 0,
        cancelled: 0,
      },
      capabilities: {
        can_update_leg: true,
        can_manage_schedule: true,
      },
    },
  };
}

function LocationEcho() {
  const location = useLocation();
  return <div data-testid="location">{`${location.pathname}${location.search}`}</div>;
}

function TestRoutes() {
  return (
    <Routes>
      <Route path="/app" element={<DashboardPage />} />
      <Route
        path="/app/today-board"
        element={
          <>
            <TodayBoardPage />
            <LocationEcho />
          </>
        }
      />
      <Route
        path="/app/shuttle"
        element={
          <>
            <ShuttleBoardPage />
            <LocationEcho />
          </>
        }
      />
      <Route
        path="/app/records"
        element={
          <>
            <CareRecordsPage />
            <LocationEcho />
          </>
        }
      />
      <Route path="*" element={<LocationEcho />} />
    </Routes>
  );
}

function renderWithRouter(initialEntry: string) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[initialEntry]}>
        <TestRoutes />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("dashboard KPI query integration", () => {
  beforeEach(() => {
    mockAuthState.permissions = ["today_board:read", "shuttles:read", "attendances:manage", "care_records:manage"];
    vi.mocked(api.getTodayBoard).mockResolvedValue(createTodayBoardResponse());
    vi.mocked(api.getShuttleBoard).mockResolvedValue(createShuttleResponse());
    vi.mocked(api.upsertAttendance).mockResolvedValue({} as never);
    vi.mocked(api.upsertCareRecord).mockResolvedValue({} as never);
    vi.mocked(api.upsertShuttleLeg).mockResolvedValue({} as never);
  });

  afterEach(() => {
    cleanup();
  });

  it("navigates from KPI card to today board and applies pending attendance filter", async () => {
    renderWithRouter("/app");

    await screen.findByTestId("kpi-value-attendance-pending");
    fireEvent.click(screen.getByTestId("kpi-card-attendance-pending"));

    await screen.findByTestId("location");
    expect(screen.getByTestId("location").textContent).toBe("/app/today-board?filter=attendance_pending");
    await screen.findByText("利用者A");
    expect(screen.queryByText("利用者B")).toBeNull();
  });

  it("navigates from KPI card to shuttle board and applies pickup pending filter", async () => {
    renderWithRouter("/app");

    await screen.findByTestId("kpi-value-shuttle-pending");
    fireEvent.click(screen.getByTestId("kpi-card-shuttle-pending"));

    await screen.findByTestId("location");
    expect(screen.getByTestId("location").textContent).toBe("/app/shuttle?direction=pickup&status=pending");
    await screen.findByText("送迎A");
    expect(screen.queryByText("送迎B")).toBeNull();
  });

  it("navigates from KPI card to records page and applies unrecorded tab", async () => {
    renderWithRouter("/app");

    await screen.findByTestId("kpi-value-record-pending");
    fireEvent.click(screen.getByTestId("kpi-card-record-pending"));

    await screen.findByTestId("location");
    expect(screen.getByTestId("location").textContent).toBe("/app/records?tab=unrecorded");
    await screen.findByText("利用者A");
    expect(screen.queryByText("利用者B")).toBeNull();
  });

  it("updates URL query when today board filter is changed on page", async () => {
    renderWithRouter("/app/today-board?filter=attendance_pending");

    await screen.findByText("利用者A");
    expect(screen.queryByText("利用者B")).toBeNull();

    fireEvent.click(screen.getByRole("button", { name: "すべて" }));

    await waitFor(() => {
      expect(screen.getByTestId("location").textContent).toBe("/app/today-board");
    });
    expect(screen.getByText("利用者B")).toBeTruthy();
  });

  it("shows unavailable marker instead of zero when today board data fetch fails", async () => {
    vi.mocked(api.getTodayBoard).mockRejectedValue(new Error("today board failed"));

    renderWithRouter("/app");

    await waitFor(() => {
      expect(screen.getByTestId("kpi-value-scheduled").textContent).toBe("--");
    });
    expect(screen.getByTestId("kpi-hint-scheduled").textContent).toBe("取得失敗");
    expect(screen.getByTestId("kpi-value-shuttle-pending").textContent).toBe("1");
  });

  it("keeps disabled actionable card semantics when permission is missing", async () => {
    mockAuthState.permissions = ["shuttles:read"];
    renderWithRouter("/app");

    await screen.findByTestId("kpi-card-attendance-pending");
    const disabledCard = screen.getByTestId("kpi-card-attendance-pending");

    expect(disabledCard.getAttribute("role")).toBe("button");
    expect(disabledCard.getAttribute("tabindex")).toBe("0");
    expect(disabledCard.getAttribute("aria-disabled")).toBe("true");

    fireEvent.click(disabledCard);
    expect(screen.queryByTestId("location")).toBeNull();
  });
});
