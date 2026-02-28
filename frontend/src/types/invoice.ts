export type InvoiceStatus = "draft" | "fixed";

export type Invoice = {
  id: number;
  tenant_id: number;
  client_id: number;
  client_name: string | null;
  billing_month: string;
  status: InvoiceStatus;
  subtotal_amount: number;
  total_amount: number;
  line_count: number | null;
  generated_at: string | null;
  generated_by_user_id: number | null;
  created_at: string;
  updated_at: string;
};

export type InvoiceLine = {
  id: number;
  tenant_id: number;
  invoice_id: number;
  attendance_id: number | null;
  price_item_id: number | null;
  service_date: string;
  item_name: string;
  quantity: number;
  unit_price: number;
  line_total: number;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
};

export type InvoiceListResult = {
  invoices: Invoice[];
  total: number;
  totalAmount: number;
  month: string;
};

export type InvoiceGenerateResult = {
  invoices: Invoice[];
  month: string;
  generated: number;
  replaced: number;
  skippedExisting: number;
  skippedFixed: number;
};

export type InvoiceMonthlyIntegrationFlow = {
  scenario: {
    care_level: string;
    benefit_limit_units: number;
    monthly_use_count: number;
    base_units: number;
    addition_units: Array<{
      code: string;
      name: string;
      units: number;
    }>;
    improvement_rate: string;
  };
  calculated: {
    daily_total_units: number;
    monthly_total_units: number;
    insured_units: number;
    self_pay_units: number;
    improvement_units: number;
  };
  expected: {
    daily_total_units: number;
    monthly_total_units: number;
    insured_units: number;
    self_pay_units: number;
    improvement_units: number;
  };
  matches_expected: boolean;
};

export type InvoiceMonthlyIntegrationCaseGenerateResult = {
  invoice: Invoice;
  flow: InvoiceMonthlyIntegrationFlow;
};
