// @vitest-environment jsdom
import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { DashboardPage } from "@/pages/dashboard-page";

const mockAuthState = vi.hoisted(() => ({
  roles: [] as string[],
  permissions: [] as string[],
}));

vi.mock("@/providers/auth-provider", () => ({
  useAuth: () => ({
    roles: mockAuthState.roles,
    permissions: mockAuthState.permissions,
  }),
}));

vi.mock("@/components/dashboard/admin-dashboard", () => ({
  AdminDashboard: () => <div>Admin Dashboard</div>,
}));

vi.mock("@/components/dashboard/staff-dashboard", () => ({
  StaffDashboard: () => <div>Staff Dashboard</div>,
}));

vi.mock("@/components/dashboard/driver-dashboard", () => ({
  DriverDashboard: () => <div>Driver Dashboard</div>,
}));

describe("DashboardPage role switch", () => {
  it("renders admin dashboard when admin role exists", () => {
    mockAuthState.roles = ["staff", "admin"];
    mockAuthState.permissions = [];

    render(<DashboardPage />);
    expect(screen.getByText("Admin Dashboard")).toBeTruthy();
  });

  it("renders driver dashboard for driver role", () => {
    mockAuthState.roles = ["driver"];
    mockAuthState.permissions = [];

    render(<DashboardPage />);
    expect(screen.getByText("Driver Dashboard")).toBeTruthy();
  });

  it("falls back to staff dashboard for unknown role set", () => {
    mockAuthState.roles = [];
    mockAuthState.permissions = ["today_board:read"];

    render(<DashboardPage />);
    expect(screen.getByText("Staff Dashboard")).toBeTruthy();
  });
});
