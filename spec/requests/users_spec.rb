require "rails_helper"

RSpec.describe "Users", type: :request do
  let!(:users_read) { Permission.create!(key: "users:read") }
  let!(:users_manage) { Permission.create!(key: "users:manage") }
  let!(:tenants_manage) { Permission.create!(key: "tenants:manage") }

  let!(:admin_role) do
    role = Role.create!(name: "admin")
    role.permissions = [users_read, users_manage, tenants_manage]
    role
  end

  let!(:staff_role) do
    role = Role.create!(name: "staff")
    role.permissions = [users_read]
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

  let!(:tenant_b_user) do
    tenant_b.users.create!(
      name: "Tenant B User",
      email: "user@b.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [admin_role]
    )
  end

  describe "tenant isolation" do
    it "returns 404 when requesting another tenant user id" do
      get "/users/#{tenant_b_user.id}", headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end

    it "returns only current tenant users on index" do
      get "/users", headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:ok)
      emails = json_body.fetch("users").map { |item| item.fetch("email") }
      expect(emails).to contain_exactly(admin_user.email, staff_user.email)
    end
  end

  describe "RBAC" do
    it "returns 403 when staff creates user" do
      post "/users", params: {
        name: "No Permission",
        email: "forbidden@a.example.com",
        password: "Password123!"
      }.to_json, headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "allows admin to create user in current tenant" do
      post "/users", params: {
        name: "Created By Admin",
        email: "created@a.example.com",
        password: "Password123!"
      }.to_json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:created)
      expect(json_body.dig("user", "email")).to eq("created@a.example.com")
      expect(User.find_by(email: "created@a.example.com")&.tenant_id).to eq(tenant_a.id)
    end
  end
end
