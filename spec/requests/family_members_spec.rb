require "rails_helper"

RSpec.describe "FamilyMembers", type: :request do
  let!(:clients_read) { Permission.find_or_create_by!(key: "clients:read") }
  let!(:clients_manage) { Permission.find_or_create_by!(key: "clients:manage") }

  let!(:admin_role) do
    role = Role.find_or_create_by!(name: "family_members_admin_#{SecureRandom.hex(4)}")
    role.permissions = [ clients_read, clients_manage ]
    role
  end

  let!(:staff_role) do
    role = Role.find_or_create_by!(name: "family_members_staff_#{SecureRandom.hex(4)}")
    role.permissions = [ clients_read ]
    role
  end

  let!(:tenant_a) { Tenant.create!(name: "Tenant A", slug: "family-members-a-#{SecureRandom.hex(4)}") }
  let!(:tenant_b) { Tenant.create!(name: "Tenant B", slug: "family-members-b-#{SecureRandom.hex(4)}") }

  let!(:admin_user) do
    tenant_a.users.create!(
      name: "Admin",
      email: "family-admin-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ admin_role ]
    )
  end

  let!(:staff_user) do
    tenant_a.users.create!(
      name: "Staff",
      email: "family-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ staff_role ]
    )
  end

  let!(:tenant_a_client) { tenant_a.clients.create!(name: "利用者A", status: :active) }
  let!(:tenant_b_client) { tenant_b.clients.create!(name: "利用者B", status: :active) }

  let!(:tenant_a_family_member) do
    tenant_a.family_members.create!(
      client: tenant_a_client,
      name: "家族A",
      relationship: "長男",
      line_enabled: false
    )
  end

  let!(:linked_family_member) do
    tenant_a.family_members.create!(
      client: tenant_a_client,
      name: "家族B",
      relationship: "配偶者",
      line_user_id: "Ulinked-#{SecureRandom.hex(8)}",
      line_enabled: true
    )
  end

  let!(:tenant_b_family_member) do
    tenant_b.family_members.create!(
      client: tenant_b_client,
      name: "家族C",
      relationship: "長女",
      line_enabled: false
    )
  end

  describe "GET /clients/:client_id/family_members" do
    it "returns 401 without token" do
      get "/clients/#{tenant_a_client.id}/family_members"

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end

    it "returns family members for authorized user" do
      get "/clients/#{tenant_a_client.id}/family_members", headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("meta", "total")).to eq(2)
      names = json_body.fetch("family_members").map { |row| row.fetch("name") }
      expect(names).to include("家族A", "家族B")
    end

    it "returns 404 for another tenant client" do
      get "/clients/#{tenant_b_client.id}/family_members", headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end
  end

  describe "POST /clients/:client_id/family_members/:id/line_invitation" do
    it "returns 403 for user without clients:manage" do
      post "/clients/#{tenant_a_client.id}/family_members/#{tenant_a_family_member.id}/line_invitation",
        as: :json,
        headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "issues invitation token for admin user" do
      tenant_a_family_member.update!(line_invitation_token: nil, line_invitation_token_generated_at: nil)

      post "/clients/#{tenant_a_client.id}/family_members/#{tenant_a_family_member.id}/line_invitation",
        as: :json,
        headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.fetch("line_invitation_token")).to be_present
      expect(json_body.fetch("line_invitation_token_generated_at")).to be_present
    end

    it "reissues token and invalidates previous token" do
      post "/clients/#{tenant_a_client.id}/family_members/#{tenant_a_family_member.id}/line_invitation",
        as: :json,
        headers: auth_headers_for(admin_user)
      expect(response).to have_http_status(:ok)
      old_token = json_body.fetch("line_invitation_token")

      post "/clients/#{tenant_a_client.id}/family_members/#{tenant_a_family_member.id}/line_invitation",
        as: :json,
        headers: auth_headers_for(admin_user)
      expect(response).to have_http_status(:ok)
      new_token = json_body.fetch("line_invitation_token")

      expect(new_token).not_to eq(old_token)

      old_result = FamilyLineIntegrationService.new(
        invitation_token: old_token,
        line_user_id: "Uold-#{SecureRandom.hex(6)}"
      ).call
      expect(old_result.success?).to eq(false)
      expect(old_result.error_code).to eq("token_not_found")
    end

    it "returns 422 for already linked family member" do
      post "/clients/#{tenant_a_client.id}/family_members/#{linked_family_member.id}/line_invitation",
        as: :json,
        headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end

    it "returns 404 for another tenant family member" do
      post "/clients/#{tenant_b_client.id}/family_members/#{tenant_b_family_member.id}/line_invitation",
        as: :json,
        headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end
  end
end
