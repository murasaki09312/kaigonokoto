require "rails_helper"

RSpec.describe "Contracts", type: :request do
  let!(:contracts_read) { Permission.create!(key: "contracts:read") }
  let!(:contracts_manage) { Permission.create!(key: "contracts:manage") }

  let!(:admin_role) do
    role = Role.create!(name: "admin")
    role.permissions = [contracts_read, contracts_manage]
    role
  end

  let!(:staff_role) do
    role = Role.create!(name: "staff")
    role.permissions = [contracts_read]
    role
  end

  let!(:tenant_a) { Tenant.create!(name: "Tenant A", slug: "tenant-a") }
  let!(:tenant_b) { Tenant.create!(name: "Tenant B", slug: "tenant-b") }

  let!(:admin_user) do
    tenant_a.users.create!(
      name: "Admin User",
      email: "admin@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [admin_role]
    )
  end

  let!(:staff_user) do
    tenant_a.users.create!(
      name: "Staff User",
      email: "staff@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [staff_role]
    )
  end

  let!(:tenant_a_client) do
    tenant_a.clients.create!(
      name: "山田 太郎",
      kana: "ヤマダ タロウ",
      status: :active
    )
  end

  let!(:tenant_b_client) do
    tenant_b.clients.create!(
      name: "佐藤 花子",
      kana: "サトウ ハナコ",
      status: :active
    )
  end

  let!(:tenant_a_contract) do
    tenant_a.contracts.create!(
      client: tenant_a_client,
      start_on: Date.new(2026, 1, 1),
      end_on: nil,
      weekdays: [1, 3, 5],
      services: { meal: true, bath: true },
      shuttle_required: true,
      shuttle_note: "朝便"
    )
  end

  let!(:tenant_b_contract) do
    tenant_b.contracts.create!(
      client: tenant_b_client,
      start_on: Date.new(2026, 2, 1),
      end_on: nil,
      weekdays: [2, 4],
      services: { meal: true },
      shuttle_required: false
    )
  end

  describe "authentication" do
    it "returns 401 without token for index" do
      get "/clients/#{tenant_a_client.id}/contracts"

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end
  end

  describe "rbac" do
    it "allows staff to read contracts" do
      get "/clients/#{tenant_a_client.id}/contracts", headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("meta", "total")).to eq(1)
      expect(json_body.fetch("contracts").first.fetch("id")).to eq(tenant_a_contract.id)
    end

    it "forbids staff to create contract" do
      post "/clients/#{tenant_a_client.id}/contracts", params: {
        start_on: "2026-02-01",
        weekdays: [1, 3],
        services: { meal: true },
        shuttle_required: true
      }, as: :json, headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "forbids staff to update contract" do
      patch "/clients/#{tenant_a_client.id}/contracts/#{tenant_a_contract.id}", params: {
        shuttle_note: "更新不可"
      }, as: :json, headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "allows admin to create contract" do
      post "/clients/#{tenant_a_client.id}/contracts", params: {
        start_on: "2026-03-01",
        weekdays: [1, 3, 5],
        services: { meal: true, bath: false },
        shuttle_required: false,
        service_note: "春季改定"
      }, as: :json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:created)
      expect(json_body.dig("contract", "client_id")).to eq(tenant_a_client.id)
      expect(json_body.dig("contract", "start_on")).to eq("2026-03-01")
    end

    it "allows admin to clear optional fields on update" do
      tenant_a_contract.update!(
        end_on: Date.new(2026, 2, 28),
        service_note: "一時メモ",
        shuttle_note: "往復送迎"
      )

      patch "/clients/#{tenant_a_client.id}/contracts/#{tenant_a_contract.id}", params: {
        end_on: nil,
        service_note: nil,
        shuttle_note: nil
      }, as: :json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:ok)
      expect(tenant_a_contract.reload.end_on).to be_nil
      expect(tenant_a_contract.service_note).to be_nil
      expect(tenant_a_contract.shuttle_note).to be_nil
    end
  end

  describe "tenant isolation" do
    it "returns 404 when accessing another tenant client contracts" do
      get "/clients/#{tenant_b_client.id}/contracts", headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end

    it "returns 404 when accessing another tenant contract id" do
      get "/clients/#{tenant_a_client.id}/contracts/#{tenant_b_contract.id}", headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end
  end

  describe "validation" do
    it "returns 422 when start_on is missing" do
      post "/clients/#{tenant_a_client.id}/contracts", params: {
        weekdays: [1, 3],
        services: { meal: true },
        shuttle_required: true
      }, as: :json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end

    it "returns 422 when end_on is before start_on" do
      post "/clients/#{tenant_a_client.id}/contracts", params: {
        start_on: "2026-03-01",
        end_on: "2026-02-28",
        weekdays: [1, 3],
        services: { meal: true },
        shuttle_required: true
      }, as: :json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end

    it "returns 422 when contract period overlaps" do
      tenant_a_contract.update!(end_on: Date.new(2026, 3, 31))
      tenant_a.contracts.create!(
        client: tenant_a_client,
        start_on: Date.new(2026, 4, 1),
        end_on: nil,
        weekdays: [2, 4],
        services: { meal: true },
        shuttle_required: false
      )

      post "/clients/#{tenant_a_client.id}/contracts", params: {
        start_on: "2026-03-20",
        weekdays: [1, 3],
        services: { meal: true },
        shuttle_required: true
      }, as: :json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end

  end

  describe "revision behavior" do
    it "updates previous active contract end_on when new revision is created" do
      post "/clients/#{tenant_a_client.id}/contracts", params: {
        start_on: "2026-02-10",
        weekdays: [1, 2, 4],
        services: { meal: true, bath: false },
        shuttle_required: false,
        shuttle_note: "送迎なし"
      }, as: :json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:created)
      expect(tenant_a_contract.reload.end_on).to eq(Date.new(2026, 2, 9))
      expect(Contract.where(client_id: tenant_a_client.id).count).to eq(2)
    end
  end

  describe "index query params" do
    it "returns 400 when as_of is invalid date" do
      get "/clients/#{tenant_a_client.id}/contracts", params: {
        as_of: "invalid-date"
      }, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:bad_request)
      expect(json_body.dig("error", "code")).to eq("bad_request")
    end
  end
end
