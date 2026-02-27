// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter } from "react-router-dom";
import type { DashboardHandoffResponse } from "@/types/dashboard-handoff";
import { HandoffWidget } from "./handoff-widget";

const mockAuthState = vi.hoisted(() => ({
  permissions: ["today_board:read"] as string[],
  user: {
    id: 1,
    tenant_id: 1,
  },
}));

vi.mock("@/providers/auth-provider", () => ({
  useAuth: () => ({
    permissions: mockAuthState.permissions,
    user: mockAuthState.user,
  }),
}));

vi.mock("@/lib/api", () => ({
  getDashboardHandoffs: vi.fn(),
}));

import * as api from "@/lib/api";

function createResponse(): DashboardHandoffResponse {
  return {
    handoffs: [
      {
        care_record_id: 1,
        reservation_id: 1,
        client_id: 1,
        client_name: "山田 太郎",
        recorded_by_user_id: 2,
        recorded_by_user_name: "記録スタッフ",
        handoff_note: "歩行時ふらつきあり。移動時は見守り継続をお願いします。",
        created_at: "2026-03-01T09:30:00+09:00",
        is_new: true,
      },
    ],
    meta: {
      total: 1,
      window_hours: 24,
      new_threshold_hours: 6,
    },
  };
}

function renderWidget() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <HandoffWidget />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("HandoffWidget", () => {
  afterEach(() => {
    cleanup();
  });

  it("renders handoff item with New badge", async () => {
    vi.mocked(api.getDashboardHandoffs).mockResolvedValue(createResponse());

    renderWidget();

    await screen.findByText("山田 太郎");
    expect(screen.getByText("New")).toBeTruthy();
    expect(screen.getByText(/記録スタッフ/)).toBeTruthy();
  });

  it("renders empty state when no handoff exists", async () => {
    vi.mocked(api.getDashboardHandoffs).mockResolvedValue({
      handoffs: [],
      meta: {
        total: 0,
        window_hours: 24,
        new_threshold_hours: 6,
      },
    });

    renderWidget();

    await screen.findByText("申し送りはまだありません");
  });

  it("shows retry button on fetch error", async () => {
    vi.mocked(api.getDashboardHandoffs).mockRejectedValueOnce(new Error("network error"));
    vi.mocked(api.getDashboardHandoffs).mockResolvedValue(createResponse());

    renderWidget();

    await screen.findByText("申し送りの取得に失敗しました");
    fireEvent.click(screen.getByRole("button", { name: "再読み込み" }));

    await waitFor(() => {
      expect(screen.getByText("山田 太郎")).toBeTruthy();
    });
  });
});
