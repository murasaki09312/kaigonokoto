require "rails_helper"

RSpec.describe "Invoices", type: :request do
  let!(:invoices_read) { Permission.find_or_create_by!(key: "invoices:read") }
  let!(:invoices_manage) { Permission.find_or_create_by!(key: "invoices:manage") }

  let!(:reader_role) do
    role = Role.find_or_create_by!(name: "reader_invoices_spec")
    role.permissions = [ invoices_read ]
    role
  end

  let!(:manager_role) do
    role = Role.find_or_create_by!(name: "manager_invoices_spec")
    role.permissions = [ invoices_read, invoices_manage ]
    role
  end

  let!(:tenant_a) { Tenant.create!(name: "Tenant A", slug: "tenant-a-invoices-#{SecureRandom.hex(4)}") }
  let!(:tenant_b) { Tenant.create!(name: "Tenant B", slug: "tenant-b-invoices-#{SecureRandom.hex(4)}") }

  let!(:reader_user) do
    tenant_a.users.create!(
      name: "Invoice Reader",
      email: "invoice-reader-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ reader_role ]
    )
  end

  let!(:manager_user) do
    tenant_a.users.create!(
      name: "Invoice Manager",
      email: "invoice-manager-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ manager_role ]
    )
  end

  let!(:tenant_a_client_1) { tenant_a.clients.create!(name: "山田 太郎", status: :active) }
  let!(:tenant_a_client_2) { tenant_a.clients.create!(name: "佐藤 花子", status: :active) }
  let!(:tenant_b_client) { tenant_b.clients.create!(name: "鈴木 次郎", status: :active) }

  let!(:tenant_a_price_item) do
    tenant_a.price_items.create!(
      code: "day_service_basic",
      name: "通所介護基本利用料",
      unit_price: 1200,
      billing_unit: :per_use,
      active: true,
      valid_from: Date.new(2026, 1, 1)
    )
  end

  let!(:tenant_b_price_item) do
    tenant_b.price_items.create!(
      code: "day_service_basic",
      name: "通所介護基本利用料",
      unit_price: 1500,
      billing_unit: :per_use,
      active: true,
      valid_from: Date.new(2026, 1, 1)
    )
  end

  let(:month) { "2026-02" }
  let(:month_start) { Date.new(2026, 2, 1) }

  let!(:a_reservation_present_1) do
    tenant_a.reservations.create!(
      client: tenant_a_client_1,
      service_date: Date.new(2026, 2, 2),
      status: :scheduled
    )
  end

  let!(:a_reservation_absent) do
    tenant_a.reservations.create!(
      client: tenant_a_client_1,
      service_date: Date.new(2026, 2, 3),
      status: :scheduled
    )
  end

  let!(:a_reservation_present_2) do
    tenant_a.reservations.create!(
      client: tenant_a_client_2,
      service_date: Date.new(2026, 2, 4),
      status: :scheduled
    )
  end

  let!(:a_reservation_other_month) do
    tenant_a.reservations.create!(
      client: tenant_a_client_2,
      service_date: Date.new(2026, 3, 1),
      status: :scheduled
    )
  end

  let!(:b_reservation_present) do
    tenant_b.reservations.create!(
      client: tenant_b_client,
      service_date: Date.new(2026, 2, 5),
      status: :scheduled
    )
  end

  let!(:a_attendance_present_1) do
    tenant_a.attendances.create!(tenant: tenant_a, reservation: a_reservation_present_1, status: :present)
  end

  let!(:a_attendance_absent) do
    tenant_a.attendances.create!(tenant: tenant_a, reservation: a_reservation_absent, status: :absent)
  end

  let!(:a_attendance_present_2) do
    tenant_a.attendances.create!(tenant: tenant_a, reservation: a_reservation_present_2, status: :present)
  end

  let!(:a_attendance_other_month) do
    tenant_a.attendances.create!(tenant: tenant_a, reservation: a_reservation_other_month, status: :present)
  end

  let!(:b_attendance_present) do
    tenant_b.attendances.create!(tenant: tenant_b, reservation: b_reservation_present, status: :present)
  end

  describe "GET /api/v1/invoices" do
    it "returns 401 without token" do
      get "/api/v1/invoices", params: { month: month }

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end

    it "allows reader to list invoices for the month" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)

      get "/api/v1/invoices", params: { month: month }, headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("meta", "month")).to eq("2026-02")
      expect(json_body.dig("meta", "total")).to eq(2)
      expect(json_body.fetch("invoices").map { |invoice| invoice.fetch("client_id") }).to contain_exactly(
        tenant_a_client_1.id,
        tenant_a_client_2.id
      )
    end
  end

  describe "GET /api/v1/invoices/monthly_integration_case" do
    it "returns 401 without token" do
      get "/api/v1/invoices/monthly_integration_case"

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end

    it "returns calculated flow result for reader" do
      get "/api/v1/invoices/monthly_integration_case", headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("scenario", "care_level")).to eq("要介護1")
      expect(json_body.dig("scenario", "monthly_use_count")).to eq(22)
      expect(json_body.dig("scenario", "benefit_limit_units")).to eq(16_765)
      expect(json_body.dig("scenario", "base_units")).to eq(658)
      expect(json_body.dig("scenario", "improvement_rate")).to eq("0.245")
      expect(json_body.dig("scenario", "addition_units")).to contain_exactly(
        { "code" => "bathing", "name" => "入浴介助加算I", "units" => 40 },
        { "code" => "individual_functional_training", "name" => "個別機能訓練加算Iロ", "units" => 76 }
      )

      expect(json_body.fetch("calculated")).to eq(
        {
          "daily_total_units" => 774,
          "monthly_total_units" => 17_028,
          "insured_units" => 16_765,
          "self_pay_units" => 263,
          "improvement_units" => 4_107
        }
      )
      expect(json_body.fetch("expected")).to eq(
        {
          "daily_total_units" => 774,
          "monthly_total_units" => 17_028,
          "insured_units" => 16_765,
          "self_pay_units" => 263,
          "improvement_units" => 4_107
        }
      )
      expect(json_body.fetch("matches_expected")).to eq(true)
    end
  end

  describe "POST /api/v1/invoices/generate" do
    it "forbids reader without invoices:manage" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "generates invoices from present attendances only" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:created)
      expect(json_body.dig("meta", "generated")).to eq(2)
      expect(json_body.dig("meta", "replaced")).to eq(0)
      expect(json_body.dig("meta", "skipped_existing")).to eq(0)
      expect(json_body.dig("meta", "skipped_fixed")).to eq(0)

      invoices = tenant_a.invoices.where(billing_month: month_start)
      expect(invoices.count).to eq(2)
      expect(invoices.sum(:total_amount)).to eq(2400)
      expect(tenant_a.invoice_lines.where(attendance_id: a_attendance_absent.id)).to be_empty
      expect(tenant_a.invoice_lines.where(attendance_id: a_attendance_other_month.id)).to be_empty
    end

    it "is idempotent with skip mode" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      first_invoice_ids = tenant_a.invoices.where(billing_month: month_start).pluck(:id).sort

      post "/api/v1/invoices/generate", params: { month: month, mode: "skip" }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:created)
      expect(json_body.dig("meta", "generated")).to eq(0)
      expect(json_body.dig("meta", "skipped_existing")).to eq(2)
      expect(tenant_a.invoices.where(billing_month: month_start).pluck(:id).sort).to eq(first_invoice_ids)
      expect(tenant_a.invoice_lines.where(invoice_id: first_invoice_ids).count).to eq(2)
    end

    it "replaces draft invoices with mode=replace" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      tenant_a_price_item.update!(unit_price: 1500)

      post "/api/v1/invoices/generate", params: { month: month, mode: "replace" }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:created)
      expect(json_body.dig("meta", "generated")).to eq(2)
      expect(json_body.dig("meta", "replaced")).to eq(2)
      expect(tenant_a.invoices.where(billing_month: month_start).sum(:total_amount)).to eq(3000)
    end

    it "removes stale draft invoices when client has no present attendance after replace" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      stale_invoice = tenant_a.invoices.find_by!(client_id: tenant_a_client_2.id, billing_month: month_start)
      a_attendance_present_2.update!(status: :absent)

      post "/api/v1/invoices/generate", params: { month: month, mode: "replace" }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:created)
      expect(json_body.dig("meta", "generated")).to eq(1)
      expect(json_body.dig("meta", "replaced")).to eq(1)
      expect(tenant_a.invoices.where(billing_month: month_start).pluck(:client_id)).to contain_exactly(tenant_a_client_1.id)
      expect(tenant_a.invoices.exists?(id: stale_invoice.id)).to be(false)
      expect(tenant_a.invoice_lines.where(attendance_id: a_attendance_present_2.id)).to be_empty
    end

    it "skips fixed invoices even with mode=replace" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      invoice = tenant_a.invoices.find_by!(client_id: tenant_a_client_1.id, billing_month: month_start)
      invoice.update!(status: :fixed)

      post "/api/v1/invoices/generate", params: { month: month, mode: "replace" }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:created)
      expect(json_body.dig("meta", "generated")).to eq(1)
      expect(json_body.dig("meta", "skipped_fixed")).to eq(1)
      expect(invoice.reload.status).to eq("fixed")
    end

    it "returns 422 when no active price item exists" do
      tenant_a.price_items.destroy_all

      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end

    it "returns 422 for invalid mode" do
      post "/api/v1/invoices/generate", params: { month: month, mode: "invalid" }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end
  end

  describe "tenant isolation" do
    it "returns invoice detail with lines in same tenant" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      invoice = tenant_a.invoices.find_by!(client_id: tenant_a_client_1.id, billing_month: month_start)

      get "/api/v1/invoices/#{invoice.id}", headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("invoice", "id")).to eq(invoice.id)
      expect(json_body.fetch("invoice_lines").size).to eq(1)
      expect(json_body.fetch("invoice_lines").first.fetch("attendance_id")).to eq(a_attendance_present_1.id)
    end

    it "returns 404 for another tenant invoice id" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      other_tenant_user = tenant_b.users.create!(
        name: "TenantB Manager",
        email: "tenantb-manager-#{SecureRandom.hex(4)}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        roles: [ manager_role ]
      )
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(other_tenant_user)
      tenant_b_invoice = tenant_b.invoices.first

      get "/api/v1/invoices/#{tenant_b_invoice.id}", headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end
  end
end
