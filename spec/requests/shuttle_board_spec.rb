require "rails_helper"

RSpec.describe "ShuttleBoard", type: :request do
  let!(:shuttles_read) { Permission.find_or_create_by!(key: "shuttles:read") }
  let!(:shuttles_operate) { Permission.find_or_create_by!(key: "shuttles:operate") }
  let!(:shuttles_manage) { Permission.find_or_create_by!(key: "shuttles:manage") }

  let!(:shuttle_manager_role) do
    role = Role.find_or_create_by!(name: "shuttle_manager_shuttle_board_spec")
    role.permissions = [ shuttles_read, shuttles_manage ]
    role
  end

  let!(:shuttle_reader_role) do
    role = Role.find_or_create_by!(name: "shuttle_reader_shuttle_board_spec")
    role.permissions = [ shuttles_read ]
    role
  end

  let!(:shuttle_driver_role) do
    role = Role.find_or_create_by!(name: "shuttle_driver_shuttle_board_spec")
    role.permissions = [ shuttles_read, shuttles_operate ]
    role
  end

  let!(:no_access_role) { Role.find_or_create_by!(name: "shuttle_no_access_shuttle_board_spec") }

  let!(:tenant_a) { Tenant.create!(name: "Tenant A", slug: "tenant-a-shuttle-#{SecureRandom.hex(4)}") }
  let!(:tenant_b) { Tenant.create!(name: "Tenant B", slug: "tenant-b-shuttle-#{SecureRandom.hex(4)}") }

  let!(:manager_user) do
    tenant_a.users.create!(
      name: "Shuttle Manager",
      email: "shuttle-manager-#{SecureRandom.hex(4)}@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ shuttle_manager_role ]
    )
  end

  let!(:reader_user) do
    tenant_a.users.create!(
      name: "Shuttle Reader",
      email: "shuttle-reader-#{SecureRandom.hex(4)}@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ shuttle_reader_role ]
    )
  end

  let!(:no_access_user) do
    tenant_a.users.create!(
      name: "No Shuttle Access",
      email: "shuttle-no-access-#{SecureRandom.hex(4)}@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ no_access_role ]
    )
  end

  let!(:driver_user) do
    tenant_a.users.create!(
      name: "Shuttle Driver",
      email: "shuttle-driver-#{SecureRandom.hex(4)}@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ shuttle_driver_role ]
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

  let!(:target_date) { Date.new(2026, 2, 27) }

  let!(:tenant_a_reservation) do
    tenant_a.reservations.create!(
      client: tenant_a_client,
      service_date: target_date,
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled,
      notes: "送迎対象"
    )
  end

  let!(:tenant_a_cancelled_reservation) do
    tenant_a.reservations.create!(
      client: tenant_a_client,
      service_date: target_date,
      start_time: "09:30",
      end_time: "16:00",
      status: :cancelled,
      notes: "送迎対象外"
    )
  end

  let!(:tenant_b_reservation) do
    tenant_b.reservations.create!(
      client: tenant_b_client,
      service_date: target_date,
      start_time: "10:00",
      end_time: "15:00",
      status: :scheduled
    )
  end

  describe "GET /api/v1/shuttle_board" do
    it "returns 401 without token" do
      get "/api/v1/shuttle_board", params: { date: target_date.to_s }

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end

    it "returns tenant-scoped shuttle items with default pending legs" do
      get "/api/v1/shuttle_board", params: { date: target_date.to_s }, headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("meta", "total")).to eq(1)
      expect(json_body.dig("meta", "pickup_counts", "pending")).to eq(1)
      expect(json_body.dig("meta", "dropoff_counts", "pending")).to eq(1)

      item = json_body.fetch("items").first
      expect(item.dig("reservation", "id")).to eq(tenant_a_reservation.id)
      expect(item.dig("shuttle_operation", "pickup_leg", "status")).to eq("pending")
      expect(item.dig("shuttle_operation", "dropoff_leg", "status")).to eq("pending")
      expect(json_body.dig("meta", "capabilities", "can_update_leg")).to eq(false)
      expect(json_body.dig("meta", "capabilities", "can_manage_schedule")).to eq(false)
    end

    it "returns shuttle capabilities by role" do
      get "/api/v1/shuttle_board", params: { date: target_date.to_s }, headers: auth_headers_for(driver_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("meta", "capabilities", "can_update_leg")).to eq(true)
      expect(json_body.dig("meta", "capabilities", "can_manage_schedule")).to eq(false)
    end

    it "returns 403 without shuttles:read permission" do
      get "/api/v1/shuttle_board", params: { date: target_date.to_s }, headers: auth_headers_for(no_access_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "returns 400 when date is invalid" do
      get "/api/v1/shuttle_board", params: { date: "invalid-date" }, headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:bad_request)
      expect(json_body.dig("error", "code")).to eq("bad_request")
    end
  end

  describe "PUT /api/v1/reservations/:reservation_id/shuttle_legs/:direction" do
    it "creates and updates pickup leg with shuttles:manage permission" do
      put "/api/v1/reservations/#{tenant_a_reservation.id}/shuttle_legs/pickup", params: {
        status: "boarded",
        note: "玄関前で乗車",
        actual_at: "2026-02-27T08:45:00+09:00"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("shuttle_leg", "status")).to eq("boarded")
      expect(json_body.dig("shuttle_leg", "direction")).to eq("pickup")
      expect(tenant_a.shuttle_operations.where(reservation_id: tenant_a_reservation.id).count).to eq(1)
      expect(tenant_a.shuttle_legs.where(shuttle_operation: tenant_a_reservation.reload.shuttle_operation).count).to eq(1)

      put "/api/v1/reservations/#{tenant_a_reservation.id}/shuttle_legs/pickup", params: {
        status: "cancelled",
        note: "体調不良により中止"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("shuttle_leg", "status")).to eq("cancelled")
      expect(tenant_a.shuttle_legs.where(tenant_id: tenant_a.id, direction: :pickup).count).to eq(1)
    end

    it "updates dropoff leg with alighted status" do
      put "/api/v1/reservations/#{tenant_a_reservation.id}/shuttle_legs/dropoff", params: {
        status: "alighted",
        note: "ご自宅前で降車"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("shuttle_leg", "direction")).to eq("dropoff")
      expect(json_body.dig("shuttle_leg", "status")).to eq("alighted")
    end

    it "allows upsert with shuttles:operate permission" do
      put "/api/v1/reservations/#{tenant_a_reservation.id}/shuttle_legs/pickup", params: {
        status: "boarded"
      }, as: :json, headers: auth_headers_for(driver_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("shuttle_leg", "status")).to eq("boarded")
    end

    it "returns 403 without shuttles:manage permission" do
      put "/api/v1/reservations/#{tenant_a_reservation.id}/shuttle_legs/pickup", params: {
        status: "boarded"
      }, as: :json, headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "returns 404 for another tenant reservation" do
      put "/api/v1/reservations/#{tenant_b_reservation.id}/shuttle_legs/pickup", params: {
        status: "boarded"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end

    it "returns 422 for invalid status" do
      put "/api/v1/reservations/#{tenant_a_reservation.id}/shuttle_legs/pickup", params: {
        status: "unknown-status"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end

    it "returns 422 when status is incompatible with direction" do
      put "/api/v1/reservations/#{tenant_a_reservation.id}/shuttle_legs/pickup", params: {
        status: "alighted"
      }, as: :json, headers: auth_headers_for(manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end
  end
end
