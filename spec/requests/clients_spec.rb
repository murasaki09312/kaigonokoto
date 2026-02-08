require "rails_helper"

RSpec.describe "Clients", type: :request do
  let!(:clients_read) { Permission.create!(key: "clients:read") }
  let!(:clients_manage) { Permission.create!(key: "clients:manage") }

  let!(:admin_role) do
    role = Role.create!(name: "admin")
    role.permissions = [clients_read, clients_manage]
    role
  end

  let!(:staff_role) do
    role = Role.create!(name: "staff")
    role.permissions = [clients_read]
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
      phone: "090-1111-1111",
      status: :active
    )
  end

  let!(:tenant_b_client) do
    tenant_b.clients.create!(
      name: "佐藤 花子",
      kana: "サトウ ハナコ",
      phone: "090-2222-2222",
      status: :active
    )
  end

  describe "authentication" do
    it "returns 401 without token for index" do
      get "/clients"

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end
  end

  describe "rbac" do
    it "allows staff to read clients" do
      get "/clients", headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.fetch("clients").size).to eq(1)
    end

    it "forbids staff to create client" do
      post "/clients", params: {
        name: "新規 利用者",
        phone: "090-1234-5678"
      }.to_json, headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "allows admin to create client" do
      post "/clients", params: {
        name: "新規 利用者",
        phone: "090-1234-5678"
      }.to_json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:created)
      expect(json_body.dig("client", "name")).to eq("新規 利用者")
      expect(Client.find_by(name: "新規 利用者")&.tenant_id).to eq(tenant_a.id)
    end
  end

  describe "tenant isolation" do
    it "returns 404 for show on another tenant client" do
      get "/clients/#{tenant_b_client.id}", headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end

    it "returns 404 for update on another tenant client" do
      patch "/clients/#{tenant_b_client.id}", params: {
        name: "Changed"
      }.to_json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end

    it "returns 404 for delete on another tenant client" do
      delete "/clients/#{tenant_b_client.id}", headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end

    it "returns only current tenant clients on index" do
      get "/clients", headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("meta", "total")).to eq(1)
      expect(json_body.fetch("clients").map { |c| c.fetch("id") }).to eq([tenant_a_client.id])
    end
  end

  describe "validation" do
    it "returns 422 when name is missing" do
      post "/clients", params: {
        phone: "090-1234-5678"
      }.to_json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end
  end
end
