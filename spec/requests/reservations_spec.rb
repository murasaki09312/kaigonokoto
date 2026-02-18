require "rails_helper"

RSpec.describe "Reservations", type: :request do
  let!(:reservations_read) { Permission.find_or_create_by!(key: "reservations:read") }
  let!(:reservations_manage) { Permission.find_or_create_by!(key: "reservations:manage") }
  let!(:reservations_override) { Permission.find_or_create_by!(key: "reservations:override_capacity") }

  let!(:staff_role) do
    role = Role.find_or_create_by!(name: "staff_reservations_spec")
    role.permissions = [reservations_read]
    role
  end

  let!(:manager_role) do
    role = Role.find_or_create_by!(name: "manager_reservations_spec")
    role.permissions = [reservations_read, reservations_manage]
    role
  end

  let!(:admin_role) do
    role = Role.find_or_create_by!(name: "admin_reservations_spec")
    role.permissions = [reservations_read, reservations_manage, reservations_override]
    role
  end

  let!(:tenant_a) { Tenant.create!(name: "Tenant A", slug: "tenant-a-#{SecureRandom.hex(4)}", capacity_per_day: 1) }
  let!(:tenant_b) { Tenant.create!(name: "Tenant B", slug: "tenant-b-#{SecureRandom.hex(4)}", capacity_per_day: 10) }

  let!(:staff_user) do
    tenant_a.users.create!(
      name: "Staff User",
      email: "staff@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [staff_role]
    )
  end

  let!(:manager_user) do
    tenant_a.users.create!(
      name: "Manager User",
      email: "manager@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [manager_role]
    )
  end

  let!(:admin_user) do
    tenant_a.users.create!(
      name: "Admin User",
      email: "admin@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [admin_role]
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

  let!(:scheduled_date) { Date.new(2026, 3, 2) }

  let!(:tenant_a_reservation) do
    tenant_a.reservations.create!(
      client: tenant_a_client,
      service_date: scheduled_date,
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled,
      notes: "既存予約"
    )
  end

  let!(:tenant_b_reservation) do
    tenant_b.reservations.create!(
      client: tenant_b_client,
      service_date: Date.new(2026, 3, 4),
      start_time: "09:00",
      end_time: "15:30",
      status: :scheduled
    )
  end

  describe "authentication" do
    it "returns 401 without token for index" do
      get "/reservations", params: { from: "2026-03-01", to: "2026-03-07" }

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end
  end

  describe "rbac" do
    it "allows staff to read reservations" do
      get "/reservations", params: { from: "2026-03-01", to: "2026-03-07" }, headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("meta", "total")).to eq(1)
    end

    it "forbids staff to create reservation" do
      post "/reservations", params: {
        client_id: tenant_a_client.id,
        service_date: "2026-03-05",
        start_time: "09:30",
        end_time: "16:00"
      }, as: :json, headers: auth_headers_for(staff_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "allows manager to create reservation" do
      post "/reservations", params: {
        client_id: tenant_a_client.id,
        service_date: "2026-03-05",
        start_time: "09:30",
        end_time: "16:00"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:created)
      expect(json_body.dig("reservation", "service_date")).to eq("2026-03-05")
    end
  end

  describe "capacity control" do
    it "returns 422 when capacity is exceeded without force" do
      post "/reservations", params: {
        client_id: tenant_a_client.id,
        service_date: scheduled_date.to_s,
        start_time: "10:00",
        end_time: "15:00"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("capacity_exceeded")
      expect(json_body.fetch("conflicts")).to include(scheduled_date.to_s)
    end

    it "does not allow force when override permission is missing" do
      post "/reservations", params: {
        client_id: tenant_a_client.id,
        service_date: scheduled_date.to_s,
        force: true
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("capacity_exceeded")
    end

    it "allows force creation when override permission exists" do
      post "/reservations", params: {
        client_id: tenant_a_client.id,
        service_date: scheduled_date.to_s,
        force: true
      }, as: :json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:created)
      expect(tenant_a.reservations.where(service_date: scheduled_date).count).to eq(2)
    end

    it "rejects second request after same-day lock is released" do
      lock_key = scheduled_date.strftime("%Y%m%d").to_i
      lock_connection = ActiveRecord::Base.connection_pool.checkout

      begin
        lock_connection.transaction do
          lock_connection.execute("SELECT pg_advisory_xact_lock(#{tenant_a.id}, #{lock_key})")

          post "/reservations", params: {
            client_id: tenant_a_client.id,
            service_date: scheduled_date.to_s,
            force: true
          }, as: :json, headers: auth_headers_for(admin_user)

          expect(response).to have_http_status(:created)
          expect(tenant_a.reservations.where(service_date: scheduled_date).count).to eq(2)
        end
      ensure
        ActiveRecord::Base.connection_pool.checkin(lock_connection)
      end

      post "/reservations", params: {
        client_id: tenant_a_client.id,
        service_date: scheduled_date.to_s
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("capacity_exceeded")
    end
  end

  describe "status validation" do
    it "returns 422 for invalid status on create" do
      post "/reservations", params: {
        client_id: tenant_a_client.id,
        service_date: "2026-03-06",
        status: "unknown"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end

    it "returns 422 for invalid status on update" do
      patch "/reservations/#{tenant_a_reservation.id}", params: {
        status: "invalid-status"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end

    it "returns 422 for invalid status on generate" do
      post "/reservations/generate", params: {
        client_id: tenant_a_client.id,
        start_on: "2026-03-09",
        end_on: "2026-03-16",
        weekdays: [1],
        status: "bad-status"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end
  end

  describe "required parameters" do
    it "returns 400 when client_id is missing" do
      post "/reservations", params: {
        service_date: "2026-03-06",
        status: "scheduled"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:bad_request)
      expect(json_body.dig("error", "code")).to eq("bad_request")
    end

    it "returns 422 when service_date is missing for scheduled reservation" do
      post "/reservations", params: {
        client_id: tenant_a_client.id,
        status: "scheduled"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end
  end

  describe "tenant isolation" do
    it "returns 404 when creating with another tenant client" do
      post "/reservations", params: {
        client_id: tenant_b_client.id,
        service_date: "2026-03-10"
      }, as: :json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end

    it "returns 404 when accessing another tenant reservation id" do
      get "/reservations/#{tenant_b_reservation.id}", headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end
  end

  describe "generate weekly reservations" do
    it "creates multiple reservations by weekday range" do
      post "/reservations/generate", params: {
        client_id: tenant_a_client.id,
        start_on: "2026-03-09",
        end_on: "2026-03-22",
        weekdays: [1, 3], # Monday and Wednesday
        start_time: "09:30",
        end_time: "16:00"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:created)
      expect(json_body.dig("meta", "total")).to eq(4)
      expect(json_body.fetch("reservations").map { |reservation| reservation.fetch("service_date") }).to contain_exactly(
        "2026-03-09",
        "2026-03-11",
        "2026-03-16",
        "2026-03-18"
      )
    end

    it "returns 422 with conflicts when any target date exceeds capacity" do
      post "/reservations/generate", params: {
        client_id: tenant_a_client.id,
        start_on: "2026-03-01",
        end_on: "2026-03-08",
        weekdays: [1], # Monday -> 2026-03-02 (already full)
        start_time: "09:30",
        end_time: "16:00"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("capacity_exceeded")
      expect(json_body.fetch("conflicts")).to contain_exactly("2026-03-02")
    end

    it "allows generate with force for override-capable user" do
      post "/reservations/generate", params: {
        client_id: tenant_a_client.id,
        start_on: "2026-03-01",
        end_on: "2026-03-08",
        weekdays: [1], # Monday -> 2026-03-02 (already full)
        force: true
      }, as: :json, headers: auth_headers_for(admin_user)

      expect(response).to have_http_status(:created)
      expect(json_body.dig("meta", "total")).to eq(1)
      expect(tenant_a.reservations.where(service_date: Date.new(2026, 3, 2)).count).to eq(2)
    end
  end
end
