require "rails_helper"

RSpec.describe "Auth", type: :request do
  let!(:tenant) { Tenant.create!(name: "Tenant A", slug: "tenant-a") }
  let!(:users_read) { Permission.create!(key: "users:read") }
  let!(:staff_role) do
    role = Role.create!(name: "staff")
    role.permissions = [users_read]
    role
  end
  let!(:user) do
    tenant.users.create!(
      name: "Admin",
      email: "admin@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [staff_role]
    )
  end

  describe "GET /auth/me" do
    it "returns 401 without token" do
      get "/auth/me"

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end

    it "returns 401 with invalid token" do
      get "/auth/me", headers: { "Authorization" => "Bearer invalid-token" }

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end

    it "returns current user and permissions with valid token" do
      get "/auth/me", headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("user", "email")).to eq(user.email)
      expect(json_body.fetch("permissions")).to include("users:read")
    end
  end

  describe "POST /auth/login" do
    it "returns token and user for valid credentials" do
      post "/auth/login", params: {
        tenant_slug: tenant.slug,
        email: user.email,
        password: "Password123!"
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body["token"]).to be_present
      expect(json_body.dig("user", "email")).to eq(user.email)
    end

    it "returns 401 when tenant_slug is invalid" do
      post "/auth/login", params: {
        tenant_slug: "wrong-slug",
        email: user.email,
        password: "Password123!"
      }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end

    it "returns 401 when password is invalid" do
      post "/auth/login", params: {
        tenant_slug: tenant.slug,
        email: user.email,
        password: "WrongPassword!"
      }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end
  end
end
