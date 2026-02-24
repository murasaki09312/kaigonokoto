require "rails_helper"

RSpec.describe "Invoices concurrency", type: :request do
  self.use_transactional_tests = false

  let!(:invoices_read) { Permission.find_or_create_by!(key: "invoices:read") }
  let!(:invoices_manage) { Permission.find_or_create_by!(key: "invoices:manage") }

  let!(:manager_role) do
    role = Role.find_or_create_by!(name: "manager_invoices_concurrency_spec")
    role.permissions = [ invoices_read, invoices_manage ]
    role
  end

  let!(:tenant) { Tenant.create!(name: "Tenant Invoice Concurrency", slug: "tenant-invoice-concurrency-#{SecureRandom.hex(4)}") }

  let!(:manager_user) do
    tenant.users.create!(
      name: "Invoice Manager",
      email: "invoice-manager-concurrency-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ manager_role ]
    )
  end

  let!(:price_item) do
    tenant.price_items.create!(
      code: "day_service_basic",
      name: "通所介護基本利用料",
      unit_price: 1200,
      billing_unit: :per_use,
      active: true,
      valid_from: Date.new(2026, 1, 1)
    )
  end

  let!(:client_a) { tenant.clients.create!(name: "利用者A", status: :active) }
  let!(:client_b) { tenant.clients.create!(name: "利用者B", status: :active) }

  let!(:reservation_a) do
    tenant.reservations.create!(client: client_a, service_date: Date.new(2026, 2, 10), status: :scheduled)
  end

  let!(:reservation_b) do
    tenant.reservations.create!(client: client_b, service_date: Date.new(2026, 2, 11), status: :scheduled)
  end

  let!(:attendance_a) { tenant.attendances.create!(reservation: reservation_a, status: :present) }
  let!(:attendance_b) { tenant.attendances.create!(reservation: reservation_b, status: :present) }

  let(:month) { "2026-02" }
  let(:month_start) { Date.new(2026, 2, 1) }

  describe "POST /api/v1/invoices/generate" do
    it "keeps invoice uniqueness with concurrent replace requests" do
      ready = Queue.new
      barrier = Queue.new
      threaded_result = spawn_generate_thread(
        month: month,
        mode: "replace",
        headers: auth_headers_for(manager_user),
        ready: ready,
        barrier: barrier
      )

      ready.pop
      barrier << true

      post "/api/v1/invoices/generate", params: { month: month, mode: "replace" }, as: :json, headers: auth_headers_for(manager_user)
      main_result = { status: response.status, body: json_body }
      thread_result = threaded_result.value

      expect(thread_result.fetch(:status)).to eq(201)
      expect(main_result.fetch(:status)).to eq(201)
      expect([ thread_result, main_result ].map { |result| result.fetch(:status) }).not_to include(500)

      invoices = tenant.invoices.where(billing_month: month_start)
      expect(invoices.count).to eq(2)
      expect(invoices.pluck(:client_id)).to contain_exactly(client_a.id, client_b.id)
      expect(tenant.invoice_lines.where(invoice_id: invoices.select(:id)).count).to eq(2)
      expect(tenant.invoice_lines.where(invoice_id: invoices.select(:id)).pluck(:attendance_id).uniq.size).to eq(2)
    end

    it "keeps invoice and line consistency with concurrent replace and skip requests" do
      ready = Queue.new
      barrier = Queue.new
      threaded_result = spawn_generate_thread(
        month: month,
        mode: "skip",
        headers: auth_headers_for(manager_user),
        ready: ready,
        barrier: barrier
      )

      ready.pop
      barrier << true

      post "/api/v1/invoices/generate", params: { month: month, mode: "replace" }, as: :json, headers: auth_headers_for(manager_user)
      replace_result = { status: response.status, body: json_body }
      skip_result = threaded_result.value

      expect(replace_result.fetch(:status)).to eq(201)
      expect(skip_result.fetch(:status)).to eq(201)
      expect([ skip_result, replace_result ].map { |result| result.fetch(:status) }).not_to include(500)

      invoices = tenant.invoices.where(billing_month: month_start)
      expect(invoices.count).to eq(2)
      expect(tenant.invoice_lines.where(invoice_id: invoices.select(:id)).count).to eq(2)
      expect(tenant.invoice_lines.where(invoice_id: invoices.select(:id)).pluck(:attendance_id).uniq.size).to eq(2)
    end
  end

  private

  def spawn_generate_thread(month:, mode:, headers:, ready:, barrier:)
    Thread.new do
      ready << true
      barrier.pop
      status = nil
      response_body = nil

      Rails.application.executor.wrap do
        env = Rack::MockRequest.env_for(
          "/api/v1/invoices/generate",
          method: "POST",
          "CONTENT_TYPE" => "application/json",
          "HTTP_AUTHORIZATION" => headers.fetch("Authorization"),
          input: { month: month, mode: mode }.to_json
        )

        app = Api::V1::InvoicesController.action(:generate)
        status, _response_headers, rack_body = app.call(env)
        response_body = +""
        rack_body.each { |chunk| response_body << chunk }
        rack_body.close if rack_body.respond_to?(:close)
      end

      {
        status: status,
        body: JSON.parse(response_body)
      }
    end
  end
end
