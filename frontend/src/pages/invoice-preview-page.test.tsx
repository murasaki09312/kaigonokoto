// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { InvoicePreviewPage } from "./invoice-preview-page";

const mockAuthState = vi.hoisted(() => ({
  permissions: ["invoices:read"] as string[],
}));

vi.mock("@/providers/auth-provider", () => ({
  useAuth: () => ({
    permissions: mockAuthState.permissions,
  }),
}));

vi.mock("@/lib/api", () => ({
  getInvoice: vi.fn(),
}));

import * as api from "@/lib/api";

function createInvoiceResponse() {
  return {
    invoice: {
      id: 42,
      tenant_id: 1,
      client_id: 10,
      client_name: "山田 太郎",
      billing_month: "2026-02",
      status: "draft" as const,
      subtotal_amount: 163500,
      total_amount: 163500,
      copayment_rate: 0.1,
      insurance_claim_amount: 147150,
      insured_copayment_amount: 16350,
      excess_copayment_amount: 0,
      copayment_amount: 16350,
      line_count: 1,
      generated_at: "2026-02-28T10:00:00+09:00",
      generated_by_user_id: 1,
      created_at: "2026-02-28T10:00:00+09:00",
      updated_at: "2026-02-28T10:00:00+09:00",
    },
    invoiceLines: [
      {
        id: 1,
        tenant_id: 1,
        invoice_id: 42,
        attendance_id: 1,
        price_item_id: 1,
        service_date: "2026-02-05",
        item_name: "通所介護基本利用料",
        quantity: 1,
        unit_price: 1200,
        line_total: 1200,
        metadata: {},
        created_at: "2026-02-28T10:00:00+09:00",
        updated_at: "2026-02-28T10:00:00+09:00",
      },
    ],
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
      <MemoryRouter initialEntries={["/app/invoices/42"]}>
        <Routes>
          <Route path="/app/invoices/:id" element={<InvoicePreviewPage />} />
          <Route path="/app/invoices" element={<div>invoices list</div>} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("InvoicePreviewPage", () => {
  afterEach(() => {
    cleanup();
  });

  it("renders invoice preview and breakdown", async () => {
    vi.mocked(api.getInvoice).mockResolvedValue(createInvoiceResponse());

    renderPage();

    await screen.findByText((content) => content.includes("山田 太郎") && content.includes("様"));
    expect(screen.getAllByText("￥16,350").length).toBeGreaterThan(0);
    expect(screen.getByText("保険請求分")).toBeTruthy();
    expect(screen.getByText("￥147,150")).toBeTruthy();
  });

  it("calls window.print when print button is clicked", async () => {
    const printSpy = vi.spyOn(window, "print").mockImplementation(() => undefined);
    vi.mocked(api.getInvoice).mockResolvedValue(createInvoiceResponse());

    renderPage();

    const printButton = await screen.findByRole("button", { name: "請求書を出力（印刷）" });
    fireEvent.click(printButton);

    await waitFor(() => {
      expect(printSpy).toHaveBeenCalledTimes(1);
    });

    printSpy.mockRestore();
  });
});
