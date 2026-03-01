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

    it "reflects copayment_rate from invoice metadata in index response" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      invoice = tenant_a.invoices.find_by!(client_id: tenant_a_client_1.id, billing_month: month_start)
      line = invoice.invoice_lines.find_by!(attendance_id: a_attendance_present_1.id)
      line.update!(metadata: line.metadata.merge("copayment_rate" => "0.2"))

      get "/api/v1/invoices", params: { month: month }, headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:ok)
      target_invoice = json_body.fetch("invoices").find { |item| item.fetch("id") == invoice.id }
      expect(target_invoice).to be_present
      expect(target_invoice.fetch("copayment_rate")).to eq(0.2)
      expect(target_invoice.fetch("insurance_claim_amount")).to eq(10_464)
      expect(target_invoice.fetch("insured_copayment_amount")).to eq(2_616)
      expect(target_invoice.fetch("copayment_amount")).to eq(2_616)
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
      expect(invoices.sum(:total_amount)).to eq(2616)
      expect(tenant_a.invoice_lines.where(attendance_id: a_attendance_absent.id)).to be_empty
      expect(tenant_a.invoice_lines.where(attendance_id: a_attendance_other_month.id)).to be_empty
    end

    it "applies client copayment rates (2 and 3) to invoice totals" do
      tenant_a_client_1.update!(copayment_rate: 2)
      tenant_a_client_2.update!(copayment_rate: 3)

      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:created)

      invoice_1 = tenant_a.invoices.find_by!(client_id: tenant_a_client_1.id, billing_month: month_start)
      invoice_2 = tenant_a.invoices.find_by!(client_id: tenant_a_client_2.id, billing_month: month_start)

      expect(invoice_1.subtotal_amount).to eq(13_080)
      expect(invoice_1.total_amount).to eq(2_616)
      expect(invoice_2.subtotal_amount).to eq(13_080)
      expect(invoice_2.total_amount).to eq(3_924)
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
      expect(tenant_a.invoices.where(billing_month: month_start).sum(:total_amount)).to eq(3270)
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
      expect(json_body.dig("invoice", "copayment_rate")).to eq(0.1)
      expect(json_body.dig("invoice", "insurance_claim_amount")).to eq(11_772)
      expect(json_body.dig("invoice", "insured_copayment_amount")).to eq(1_308)
      expect(json_body.dig("invoice", "excess_copayment_amount")).to eq(0)
      expect(json_body.dig("invoice", "copayment_amount")).to eq(1_308)
      expect(json_body.fetch("invoice_lines").size).to eq(1)
      expect(json_body.fetch("invoice_lines").first.fetch("attendance_id")).to eq(a_attendance_present_1.id)
      expect(json_body.fetch("invoice_lines").first.fetch("units")).to eq(1200)
      expect(json_body.fetch("invoice_lines").first).not_to have_key("unit_price")
      expect(json_body.fetch("invoice_lines").first).not_to have_key("line_total")
    end

    it "uses copayment rate from invoice line metadata when present" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      invoice = tenant_a.invoices.find_by!(client_id: tenant_a_client_1.id, billing_month: month_start)
      line = invoice.invoice_lines.find_by!(attendance_id: a_attendance_present_1.id)
      line.update!(metadata: line.metadata.merge("copayment_rate" => "0.2"))

      get "/api/v1/invoices/#{invoice.id}", headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("invoice", "copayment_rate")).to eq(0.2)
      expect(json_body.dig("invoice", "insurance_claim_amount")).to eq(10_464)
      expect(json_body.dig("invoice", "insured_copayment_amount")).to eq(2_616)
      expect(json_body.dig("invoice", "copayment_amount")).to eq(2_616)
    end

    it "falls back to default copayment rate when metadata has invalid copayment_rate" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      invoice = tenant_a.invoices.find_by!(client_id: tenant_a_client_1.id, billing_month: month_start)
      line = invoice.invoice_lines.find_by!(attendance_id: a_attendance_present_1.id)
      line.update!(metadata: line.metadata.merge("copayment_rate" => "abc"))

      get "/api/v1/invoices/#{invoice.id}", headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("invoice", "copayment_rate")).to eq(0.1)
      expect(json_body.dig("invoice", "insurance_claim_amount")).to eq(11_772)
      expect(json_body.dig("invoice", "insured_copayment_amount")).to eq(1_308)
      expect(json_body.dig("invoice", "copayment_amount")).to eq(1_308)
    end

    it "keeps historical invoice breakdown immutable after client copayment changes" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      invoice = tenant_a.invoices.find_by!(client_id: tenant_a_client_1.id, billing_month: month_start)
      line = invoice.invoice_lines.find_by!(attendance_id: a_attendance_present_1.id)

      line.update!(metadata: line.metadata.except("copayment_rate"))
      tenant_a_client_1.update!(copayment_rate: 2)

      get "/api/v1/invoices/#{invoice.id}", headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:ok)
      expect(invoice.reload.copayment_rate).to eq(1)
      expect(json_body.dig("invoice", "copayment_rate")).to eq(0.1)
      expect(json_body.dig("invoice", "insurance_claim_amount")).to eq(11_772)
      expect(json_body.dig("invoice", "insured_copayment_amount")).to eq(1_308)
      expect(json_body.dig("invoice", "copayment_amount")).to eq(1_308)
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

    it "returns persisted excess copayment amount for invoices with limit overflow" do
      invoice = tenant_a.invoices.create!(
        tenant: tenant_a,
        client: tenant_a_client_1,
        billing_month: month_start,
        status: :draft,
        copayment_rate: 1,
        subtotal_amount: 227_504,
        total_amount: 25_617,
        insurance_claim_amount: 204_753,
        insured_copayment_amount: 22_751,
        excess_copayment_amount: 2_866,
        generated_by_user: manager_user,
        generated_at: Time.current
      )
      invoice.invoice_lines.create!(
        tenant: tenant_a,
        attendance: a_attendance_present_1,
        price_item: tenant_a_price_item,
        service_date: Date.new(2026, 2, 2),
        item_name: "通所介護基本報酬",
        quantity: 1.0,
        unit_price: 658,
        line_total: 658,
        metadata: {
          "service_code" => "151111",
          "units" => 658,
          "copayment_rate" => "0.1"
        }
      )

      get "/api/v1/invoices/#{invoice.id}", headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("invoice", "copayment_rate")).to eq(0.1)
      expect(json_body.dig("invoice", "insurance_claim_amount")).to eq(204_753)
      expect(json_body.dig("invoice", "insured_copayment_amount")).to eq(22_751)
      expect(json_body.dig("invoice", "excess_copayment_amount")).to eq(2_866)
      expect(json_body.dig("invoice", "copayment_amount")).to eq(25_617)
    end
  end

  describe "GET /api/v1/invoices/:id/receipt" do
    it "returns aggregated receipt items sorted by service_code" do
      extra_reservation = tenant_a.reservations.create!(
        client: tenant_a_client_1,
        service_date: Date.new(2026, 2, 6),
        status: :scheduled
      )
      extra_attendance = tenant_a.attendances.create!(
        tenant: tenant_a,
        reservation: extra_reservation,
        status: :present
      )

      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      invoice = tenant_a.invoices.find_by!(client_id: tenant_a_client_1.id, billing_month: month_start)
      lines = invoice.invoice_lines.where(attendance_id: [ a_attendance_present_1.id, extra_attendance.id ]).order(:id).to_a

      lines.first.update!(
        item_name: "入浴介助加算I",
        metadata: lines.first.metadata.merge("service_code" => "155011", "units" => 40)
      )
      lines.second.update!(
        item_name: "通所介護基本報酬",
        metadata: lines.second.metadata.merge("service_code" => "151111", "units" => 658)
      )

      get "/api/v1/invoices/#{invoice.id}/receipt", headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.fetch("receipt_items").map { |item| item.fetch("service_code") }).to eq(%w[151111 155011])

      basic_item = json_body.fetch("receipt_items").first
      expect(basic_item.fetch("name")).to eq("通所介護基本報酬")
      expect(basic_item.fetch("unit_score")).to eq(658)
      expect(basic_item.fetch("count")).to eq(1)
      expect(basic_item.fetch("total_units")).to eq(658)

      bathing_item = json_body.fetch("receipt_items").second
      expect(bathing_item.fetch("name")).to eq("入浴介助加算I")
      expect(bathing_item.fetch("unit_score")).to eq(40)
      expect(bathing_item.fetch("count")).to eq(1)
      expect(bathing_item.fetch("total_units")).to eq(40)

      expect(json_body.dig("meta", "total_units")).to eq(698)
    end

    it "returns 404 for another tenant invoice id" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      other_tenant_user = tenant_b.users.create!(
        name: "TenantB Manager Receipt",
        email: "tenantb-manager-receipt-#{SecureRandom.hex(4)}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        roles: [ manager_role ]
      )
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(other_tenant_user)
      tenant_b_invoice = tenant_b.invoices.first

      get "/api/v1/invoices/#{tenant_b_invoice.id}/receipt", headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end

    it "returns 422 instead of 500 when receipt items contain unit mismatch for the same service code" do
      post "/api/v1/invoices/generate", params: { month: month }, as: :json, headers: auth_headers_for(manager_user)
      invoice = tenant_a.invoices.find_by!(client_id: tenant_a_client_1.id, billing_month: month_start)

      extra_reservation = tenant_a.reservations.create!(
        client: tenant_a_client_1,
        service_date: Date.new(2026, 2, 7),
        status: :scheduled
      )
      extra_attendance = tenant_a.attendances.create!(
        tenant: tenant_a,
        reservation: extra_reservation,
        status: :present
      )
      invoice.invoice_lines.create!(
        tenant: tenant_a,
        attendance: extra_attendance,
        price_item: tenant_a_price_item,
        service_date: extra_reservation.service_date,
        item_name: "通所介護基本利用料",
        quantity: 1.0,
        unit_price: 1200,
        line_total: 1200,
        metadata: {
          "service_code" => "151111",
          "units" => 1300
        }
      )

      get "/api/v1/invoices/#{invoice.id}/receipt", headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
      expect(json_body.dig("error", "message")).to include("unit score mismatch")
    end
  end
end
