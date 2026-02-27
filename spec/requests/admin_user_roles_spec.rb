require "rails_helper"

RSpec.describe "Admin::UserRoles", type: :request do
  let!(:users_read) { Permission.find_or_create_by!(key: "users:read") }
  let!(:users_manage) { Permission.find_or_create_by!(key: "users:manage") }

  let!(:admin_role) do
    role = Role.find_or_create_by!(name: "admin")
    role.permissions = [ users_read, users_manage ]
    role
  end

  let!(:staff_role) do
    role = Role.find_or_create_by!(name: "staff")
    role.permissions = [ users_read ]
    role
  end

  let!(:driver_role) do
    role = Role.find_or_create_by!(name: "driver")
    role.permissions = []
    role
  end

  let!(:tenant_a) { Tenant.create!(name: "Tenant A", slug: "tenant-a-admin-#{SecureRandom.hex(3)}") }
  let!(:tenant_b) { Tenant.create!(name: "Tenant B", slug: "tenant-b-admin-#{SecureRandom.hex(3)}") }

  let!(:admin_user) do
    tenant_a.users.create!(
      name: "Admin User",
      email: "admin-#{SecureRandom.hex(4)}@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ admin_role ]
    )
  end

  let!(:staff_user) do
    tenant_a.users.create!(
      name: "Staff User",
      email: "staff-#{SecureRandom.hex(4)}@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ staff_role ]
    )
  end

  let!(:tenant_b_user) do
    tenant_b.users.create!(
      name: "Tenant B User",
      email: "tenant-b-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ admin_role ]
    )
  end

  describe "GET /api/v1/admin/users" do
    it "returns 401 without token" do
      get "/api/v1/admin/users"

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end

    it "returns 403 for non-admin user" do
      get "/api/v1/admin/users", headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "returns tenant-scoped users and role options for admin" do
      get "/api/v1/admin/users", headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("meta", "current_user_id")).to eq(admin_user.id)
      expect(json_body.dig("meta", "can_manage_roles")).to eq(true)

      user_emails = json_body.fetch("users").map { |user| user.fetch("email") }
      expect(user_emails).to contain_exactly(admin_user.email, staff_user.email)
      expect(json_body.fetch("role_options").map { |option| option.fetch("name") }).to contain_exactly("admin", "staff", "driver")
    end
  end

  describe "PATCH /api/v1/admin/users/:id/roles" do
    it "returns 403 when user does not have users:manage" do
      patch "/api/v1/admin/users/#{staff_user.id}/roles",
        params: { role_names: [ "driver" ] }.to_json,
        headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "returns 404 when target user belongs to another tenant" do
      patch "/api/v1/admin/users/#{tenant_b_user.id}/roles",
        params: { role_names: [ "driver" ] }.to_json,
        headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end

    it "updates roles for tenant user" do
      patch "/api/v1/admin/users/#{staff_user.id}/roles",
        params: { role_names: [ "driver" ] }.to_json,
        headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("user", "role_names")).to eq([ "driver" ])
      expect(staff_user.reload.roles.pluck(:name)).to eq([ "driver" ])
    end

    it "returns 422 when admin attempts to remove own admin role" do
      patch "/api/v1/admin/users/#{admin_user.id}/roles",
        params: { role_names: [ "staff" ] }.to_json,
        headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
      expect(admin_user.reload.roles.pluck(:name)).to include("admin")
    end

    it "returns 422 for unsupported role names" do
      patch "/api/v1/admin/users/#{staff_user.id}/roles",
        params: { role_names: [ "super_admin" ] }.to_json,
        headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end

    it "returns 422 when multiple roles are provided" do
      patch "/api/v1/admin/users/#{staff_user.id}/roles",
        params: { role_names: [ "staff", "driver" ] }.to_json,
        headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end
  end
end
