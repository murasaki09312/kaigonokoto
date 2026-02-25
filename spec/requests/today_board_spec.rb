require "rails_helper"

RSpec.describe "TodayBoard", type: :request do
  let!(:today_board_read) { Permission.find_or_create_by!(key: "today_board:read") }
  let!(:attendances_manage) { Permission.find_or_create_by!(key: "attendances:manage") }
  let!(:care_records_manage) { Permission.find_or_create_by!(key: "care_records:manage") }

  let!(:board_manager_role) do
    role = Role.find_or_create_by!(name: "board_manager_today_board_spec")
    role.permissions = [ today_board_read, attendances_manage, care_records_manage ]
    role
  end

  let!(:board_reader_role) do
    role = Role.find_or_create_by!(name: "board_reader_today_board_spec")
    role.permissions = [ today_board_read ]
    role
  end

  let!(:no_access_role) { Role.find_or_create_by!(name: "board_no_access_today_board_spec") }

  let!(:tenant_a) { Tenant.create!(name: "Tenant A", slug: "tenant-a-#{SecureRandom.hex(4)}") }
  let!(:tenant_b) { Tenant.create!(name: "Tenant B", slug: "tenant-b-#{SecureRandom.hex(4)}") }

  let!(:board_manager_user) do
    tenant_a.users.create!(
      name: "Board Manager",
      email: "board-manager-#{SecureRandom.hex(4)}@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ board_manager_role ]
    )
  end

  let!(:board_reader_user) do
    tenant_a.users.create!(
      name: "Board Reader",
      email: "board-reader-#{SecureRandom.hex(4)}@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ board_reader_role ]
    )
  end

  let!(:no_access_user) do
    tenant_a.users.create!(
      name: "No Access",
      email: "board-no-access-#{SecureRandom.hex(4)}@a.example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ no_access_role ]
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

  let!(:target_date) { Date.new(2026, 2, 24) }

  let!(:tenant_a_reservation) do
    tenant_a.reservations.create!(
      client: tenant_a_client,
      service_date: target_date,
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled,
      notes: "当日ボード対象"
    )
  end

  let!(:tenant_b_reservation) do
    tenant_b.reservations.create!(
      client: tenant_b_client,
      service_date: target_date,
      start_time: "09:00",
      end_time: "15:00",
      status: :scheduled
    )
  end

  describe "GET /api/v1/today_board" do
    it "returns 401 without token" do
      get "/api/v1/today_board", params: { date: target_date.to_s }

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end

    it "returns integrated reservation, attendance, and care record data" do
      tenant_a.attendances.create!(
        tenant: tenant_a,
        reservation: tenant_a_reservation,
        status: :present,
        note: "到着済み"
      )
      tenant_a.care_records.create!(
        tenant: tenant_a,
        reservation: tenant_a_reservation,
        recorded_by_user: board_manager_user,
        body_temperature: 36.5,
        care_note: "バイタル安定"
      )

      get "/api/v1/today_board", params: { date: target_date.to_s }, headers: auth_headers_for(board_reader_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("meta", "total")).to eq(1)
      expect(json_body.dig("meta", "attendance_counts", "present")).to eq(1)
      expect(json_body.dig("meta", "care_record_completed")).to eq(1)

      item = json_body.fetch("items").first
      expect(item.dig("reservation", "id")).to eq(tenant_a_reservation.id)
      expect(item.dig("attendance", "status")).to eq("present")
      expect(item.dig("care_record", "care_note")).to eq("バイタル安定")
    end

    it "returns line notification availability and latest line notification summary" do
      care_record = tenant_a.care_records.create!(
        tenant: tenant_a,
        reservation: tenant_a_reservation,
        recorded_by_user: board_manager_user,
        handoff_note: "申し送りメモ"
      )

      tenant_a.family_members.create!(
        client: tenant_a_client,
        name: "家族A",
        relationship: "長男",
        line_user_id: "Utoday-board-spec-#{SecureRandom.hex(4)}",
        line_enabled: true,
        active: true
      )

      tenant_a.notification_logs.create!(
        client: tenant_a_client,
        family_member: tenant_a.family_members.first,
        event_name: CareRecordHandoffEventPublisher::EVENT_NAME,
        source_type: "CareRecord",
        source_id: care_record.id,
        channel: :line,
        status: :failed,
        error_code: "line_api_error",
        error_message: "LINE gateway error",
        idempotency_key: "today-board-line-log-#{SecureRandom.hex(8)}"
      )

      get "/api/v1/today_board", params: { date: target_date.to_s }, headers: auth_headers_for(board_reader_user)

      expect(response).to have_http_status(:ok)
      item = json_body.fetch("items").first

      expect(item.fetch("line_notification_available")).to eq(true)
      expect(item.fetch("line_linked_family_count")).to eq(1)
      expect(item.fetch("line_enabled_family_count")).to eq(1)
      expect(item.dig("line_notification", "status")).to eq("failed")
      expect(item.dig("line_notification", "failed_count")).to eq(1)
      expect(item.dig("line_notification", "last_error_code")).to eq("line_api_error")
    end

    it "returns 403 without today_board:read permission" do
      get "/api/v1/today_board", params: { date: target_date.to_s }, headers: auth_headers_for(no_access_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "returns 400 when date format is invalid" do
      get "/api/v1/today_board", params: { date: "invalid-date" }, headers: auth_headers_for(board_reader_user)

      expect(response).to have_http_status(:bad_request)
      expect(json_body.dig("error", "code")).to eq("bad_request")
    end
  end

  describe "PUT /api/v1/reservations/:reservation_id/attendance" do
    it "creates and updates attendance with manage permission" do
      put "/api/v1/reservations/#{tenant_a_reservation.id}/attendance", params: {
        status: "absent",
        absence_reason: "体調不良",
        contacted_at: "2026-02-24T08:30:00+09:00",
        note: "朝連絡あり"
      }, as: :json, headers: auth_headers_for(board_manager_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("attendance", "status")).to eq("absent")
      expect(tenant_a_reservation.reload.attendance&.absence_reason).to eq("体調不良")

      put "/api/v1/reservations/#{tenant_a_reservation.id}/attendance", params: {
        status: "present",
        absence_reason: nil,
        note: "来所済み"
      }, as: :json, headers: auth_headers_for(board_manager_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("attendance", "status")).to eq("present")
      expect(tenant_a.attendances.where(reservation_id: tenant_a_reservation.id).count).to eq(1)
    end

    it "returns 403 without attendances:manage permission" do
      put "/api/v1/reservations/#{tenant_a_reservation.id}/attendance", params: {
        status: "present"
      }, as: :json, headers: auth_headers_for(board_reader_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "returns 404 for another tenant reservation" do
      put "/api/v1/reservations/#{tenant_b_reservation.id}/attendance", params: {
        status: "present"
      }, as: :json, headers: auth_headers_for(board_manager_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end

    it "returns 422 for invalid status" do
      put "/api/v1/reservations/#{tenant_a_reservation.id}/attendance", params: {
        status: "unknown-status"
      }, as: :json, headers: auth_headers_for(board_manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end
  end

  describe "PUT /api/v1/reservations/:reservation_id/care_record" do
    it "creates and updates care record with manage permission" do
      put "/api/v1/reservations/#{tenant_a_reservation.id}/care_record", params: {
        body_temperature: 36.7,
        systolic_bp: 118,
        diastolic_bp: 72,
        pulse: 68,
        spo2: 98,
        care_note: "午前レク参加",
        handoff_note: "水分摂取良好"
      }, as: :json, headers: auth_headers_for(board_manager_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("care_record", "body_temperature")).to eq("36.7")
      expect(json_body.dig("care_record", "recorded_by_user_id")).to eq(board_manager_user.id)

      put "/api/v1/reservations/#{tenant_a_reservation.id}/care_record", params: {
        care_note: "午後は静養",
        handoff_note: "家族へ共有済み"
      }, as: :json, headers: auth_headers_for(board_manager_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("care_record", "care_note")).to eq("午後は静養")
      expect(tenant_a.care_records.where(reservation_id: tenant_a_reservation.id).count).to eq(1)
    end

    it "returns 403 without care_records:manage permission" do
      put "/api/v1/reservations/#{tenant_a_reservation.id}/care_record", params: {
        care_note: "保存不可"
      }, as: :json, headers: auth_headers_for(board_reader_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "returns 404 for another tenant reservation" do
      put "/api/v1/reservations/#{tenant_b_reservation.id}/care_record", params: {
        care_note: "越境アクセス"
      }, as: :json, headers: auth_headers_for(board_manager_user)

      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end

    it "returns 422 for out-of-range vitals" do
      put "/api/v1/reservations/#{tenant_a_reservation.id}/care_record", params: {
        body_temperature: 52.0
      }, as: :json, headers: auth_headers_for(board_manager_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("validation_error")
    end
  end
end
