// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { ReceiptPreviewPage } from "./receipt-preview-page";

const mockAuthState = vi.hoisted(() => ({
  permissions: ["invoices:read"] as string[],
}));

vi.mock("@/providers/auth-provider", () => ({
  useAuth: () => ({
    permissions: mockAuthState.permissions,
  }),
}));

vi.mock("@/lib/api", () => ({
  getInvoiceReceipt: vi.fn(),
}));

import * as api from "@/lib/api";

function createReceiptResponse() {
  return {
    invoice: {
      id: 42,
      tenant_id: 1,
      client_id: 10,
      client_name: "山田 太郎",
      billing_month: "2026-02",
      status: "draft" as const,
      subtotal_amount: 163500,
      total_amount: 16350,
      copayment_rate: 0.1,
      insurance_claim_amount: 147150,
      insured_copayment_amount: 16350,
      excess_copayment_amount: 0,
      copayment_amount: 16350,
      line_count: 2,
      generated_at: "2026-02-28T10:00:00+09:00",
      generated_by_user_id: 1,
      created_at: "2026-02-28T10:00:00+09:00",
      updated_at: "2026-02-28T10:00:00+09:00",
    },
    receiptItems: [
      {
        service_code: "151111",
        name: "通所介護基本報酬",
        unit_score: 658,
        count: 22,
        total_units: 14476,
      },
      {
        service_code: "155011",
        name: "入浴介助加算I",
        unit_score: 40,
        count: 10,
        total_units: 400,
      },
    ],
    totalUnits: 14876,
  };
}

function renderPage() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={["/app/invoices/42/receipt"]}>
        <Routes>
          <Route path="/app/invoices/:id/receipt" element={<ReceiptPreviewPage />} />
          <Route path="/app/invoices/:id" element={<div>invoice preview</div>} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("ReceiptPreviewPage", () => {
  afterEach(() => {
    cleanup();
  });

  it("renders receipt items and monthly total units", async () => {
    vi.mocked(api.getInvoiceReceipt).mockResolvedValue(createReceiptResponse());

    renderPage();

    await screen.findByText("151111");
    expect(screen.getByText("サービスコード")).toBeTruthy();
    expect(screen.getByText("151111")).toBeTruthy();
    expect(screen.getByText("155011")).toBeTruthy();
    expect(screen.getByText("14,876 単位")).toBeTruthy();
  });
});
