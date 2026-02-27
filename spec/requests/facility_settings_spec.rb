require "rails_helper"

RSpec.describe "FacilitySettings", type: :request do
  let!(:tenants_manage) { Permission.find_or_create_by!(key: "tenants:manage") }

  let!(:admin_role) do
    role = Role.find_or_create_by!(name: "facility_admin")
    role.permissions = [ tenants_manage ]
    role
  end

  let!(:staff_role) { Role.find_or_create_by!(name: "facility_staff") }

  let!(:tenant_a) do
    Tenant.create!(
      name: "Tenant A",
      slug: "facility-a-#{SecureRandom.hex(4)}",
      city_name: "目黒区",
      facility_scale: :normal
    )
  end
  let!(:tenant_b) do
    Tenant.create!(
      name: "Tenant B",
      slug: "facility-b-#{SecureRandom.hex(4)}",
      city_name: "港区",
      facility_scale: :large_1
    )
  end

  let!(:admin_user) do
    tenant_a.users.create!(
      name: "Admin",
      email: "facility-admin-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ admin_role ]
    )
  end
  let!(:staff_user) do
    tenant_a.users.create!(
      name: "Staff",
      email: "facility-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ staff_role ]
    )
  end

  describe "GET /api/v1/settings/facility" do
    it "returns 401 without token" do
      get "/api/v1/settings/facility"

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end

    it "returns 403 without tenants:manage permission" do
      get "/api/v1/settings/facility", headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "returns current tenant facility settings with options" do
      get "/api/v1/settings/facility", headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:ok)
      setting = json_body.fetch("facility_setting")
      expect(setting.fetch("tenant_id")).to eq(tenant_a.id)
      expect(setting.fetch("city_name")).to eq("目黒区")
      expect(setting.fetch("facility_scale")).to eq("normal")
      expect(setting.fetch("city_options")).to include("目黒区", "江戸川区")
      expect(setting.fetch("facility_scale_options").map { |option| option.fetch("value") })
        .to contain_exactly("normal", "large_1", "large_2")
    end
  end

  describe "PATCH /api/v1/settings/facility" do
    it "updates current tenant facility settings for admin" do
      patch "/api/v1/settings/facility",
        params: { city_name: "渋谷区", facility_scale: "large_2" }.to_json,
        headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("facility_setting", "city_name")).to eq("渋谷区")
      expect(json_body.dig("facility_setting", "facility_scale")).to eq("large_2")
      expect(tenant_a.reload.city_name).to eq("渋谷区")
      expect(tenant_a.reload.facility_scale).to eq("large_2")
      expect(tenant_b.reload.city_name).to eq("港区")
      expect(tenant_b.reload.facility_scale).to eq("large_1")
    end

    it "returns 422 for invalid facility_scale" do
      patch "/api/v1/settings/facility",
        params: { city_name: "渋谷区", facility_scale: "invalid_scale" }.to_json,
        headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end

    it "returns 422 for unsupported city_name" do
      patch "/api/v1/settings/facility",
        params: { city_name: "調布市", facility_scale: "normal" }.to_json,
        headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end
  end
end
