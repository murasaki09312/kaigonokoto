// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { AuthProvider } from "@/providers/auth-provider";
import { ProtectedRoute, PublicOnlyRoute } from "@/components/common/route-guards";
import { LoginPage } from "@/pages/login-page";
import type { LoginResponse, MeResponse, User } from "@/types/auth";
import * as api from "@/lib/api";

const mockAuthState = vi.hoisted(() => ({
  token: null as string | null,
  permissions: ["clients:read"] as string[],
}));

const mockUser: User = {
  id: 1,
  tenant_id: 1,
  name: "Test User",
  email: "test@example.com",
  created_at: "2026-01-01T00:00:00Z",
  updated_at: "2026-01-01T00:00:00Z",
};

vi.mock("@/lib/api", () => {
  return {
    login: vi.fn(async (): Promise<LoginResponse> => ({
      token: "token-1",
      user: mockUser,
    })),
    logout: vi.fn(async (): Promise<void> => {}),
    me: vi.fn(async (): Promise<MeResponse> => ({
      user: mockUser,
      permissions: mockAuthState.permissions,
    })),
    getToken: vi.fn((): string | null => mockAuthState.token),
    setToken: vi.fn((nextToken: string | null): void => {
      mockAuthState.token = nextToken;
    }),
  };
});

function TestApp() {
  return (
    <Routes>
      <Route element={<PublicOnlyRoute />}>
        <Route path="/login" element={<LoginPage />} />
      </Route>

      <Route element={<ProtectedRoute />}>
        <Route path="/app" element={<div>Dashboard Screen</div>} />
        <Route path="/app/today-board" element={<div>Today Board Screen</div>} />
        <Route path="/app/clients" element={<div>Clients Screen</div>} />
        <Route path="/app/clients/:id" element={<div>Client Detail Screen</div>} />
        <Route path="/app/reservations" element={<div>Reservations Screen</div>} />
        <Route path="/app/shuttle" element={<div>Shuttle Screen</div>} />
        <Route path="/app/users" element={<div>Users Screen</div>} />
      </Route>

      <Route path="*" element={<div>Not Found Screen</div>} />
    </Routes>
  );
}

function renderWithAuthRoute(initialEntry: string) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <MemoryRouter initialEntries={[initialEntry]}>
          <TestApp />
        </MemoryRouter>
      </AuthProvider>
    </QueryClientProvider>,
  );
}

function submitLoginForm() {
  fireEvent.change(screen.getByLabelText("Tenant Slug"), {
    target: { value: "demo-dayservice" },
  });
  fireEvent.change(screen.getByLabelText("Email"), {
    target: { value: "test@example.com" },
  });
  fireEvent.change(screen.getByLabelText("Password"), {
    target: { value: "Password123!" },
  });
  fireEvent.click(screen.getByRole("button", { name: "ログイン" }));
}

describe("auth routing integration", () => {
  afterEach(() => {
    cleanup();
  });

  beforeEach(() => {
    mockAuthState.token = null;
    mockAuthState.permissions = ["clients:read"];

    vi.mocked(api.login).mockResolvedValue({ token: "token-1", user: mockUser });
    vi.mocked(api.me).mockImplementation(async () => ({
      user: mockUser,
      permissions: mockAuthState.permissions,
    }));
    vi.mocked(api.logout).mockResolvedValue();

    vi.mocked(api.getToken).mockImplementation(() => mockAuthState.token);
    vi.mocked(api.setToken).mockImplementation((nextToken) => {
      mockAuthState.token = nextToken;
    });
  });

  it("keeps authenticated state after login and lands on operations screen", async () => {
    renderWithAuthRoute("/login");

    submitLoginForm();

    await screen.findByText("Clients Screen");
    expect(screen.queryByText("Welcome back")).toBeNull();
  });

  it("returns to requested route when permitted", async () => {
    mockAuthState.permissions = ["users:read"];

    renderWithAuthRoute("/app/users");

    await screen.findByText("Welcome back");
    submitLoginForm();

    await screen.findByText("Users Screen");
  });

  it("falls back when requested route is not permitted", async () => {
    mockAuthState.permissions = ["users:read"];

    renderWithAuthRoute("/app/clients/42");

    await screen.findByText("Welcome back");
    submitLoginForm();

    await screen.findByText("Users Screen");
    expect(screen.queryByText("Client Detail Screen")).toBeNull();
  });

  it("falls back to reservations screen when only reservations:read is granted", async () => {
    mockAuthState.permissions = ["reservations:read"];

    renderWithAuthRoute("/login");

    submitLoginForm();

    await screen.findByText("Reservations Screen");
    expect(screen.queryByText("Welcome back")).toBeNull();
  });

  it("falls back to shuttle screen when only shuttles:read is granted", async () => {
    mockAuthState.permissions = ["shuttles:read"];

    renderWithAuthRoute("/login");

    submitLoginForm();

    await screen.findByText("Shuttle Screen");
    expect(screen.queryByText("Welcome back")).toBeNull();
  });

  it("redirects already signed-in user from /login", async () => {
    mockAuthState.token = "existing-token";
    mockAuthState.permissions = ["users:read"];

    renderWithAuthRoute("/login");

    await waitFor(() => {
      expect(screen.getByText("Users Screen")).toBeTruthy();
    });
    expect(screen.queryByText("Welcome back")).toBeNull();
  });
});
