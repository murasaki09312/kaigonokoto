require "rails_helper"

RSpec.describe "Dashboard::Handoffs", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:today_board_read) { Permission.find_or_create_by!(key: "today_board:read") }

  let!(:reader_role) do
    role = Role.find_or_create_by!(name: "dashboard_handoff_reader_spec")
    role.permissions = [ today_board_read ]
    role
  end

  let!(:no_access_role) { Role.find_or_create_by!(name: "dashboard_handoff_no_access_spec") }

  let!(:tenant_a) { Tenant.create!(name: "Tenant A", slug: "dashboard-handoff-a-#{SecureRandom.hex(4)}") }
  let!(:tenant_b) { Tenant.create!(name: "Tenant B", slug: "dashboard-handoff-b-#{SecureRandom.hex(4)}") }

  let!(:reader_user) do
    tenant_a.users.create!(
      name: "Reader User",
      email: "dashboard-reader-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ reader_role ]
    )
  end

  let!(:no_access_user) do
    tenant_a.users.create!(
      name: "No Access User",
      email: "dashboard-no-access-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ no_access_role ]
    )
  end

  let!(:tenant_a_client) { tenant_a.clients.create!(name: "山田 太郎", status: :active) }
  let!(:tenant_b_client) { tenant_b.clients.create!(name: "佐藤 花子", status: :active) }

  let!(:tenant_a_staff) do
    tenant_a.users.create!(
      name: "記録スタッフA",
      email: "dashboard-staff-a-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  let!(:tenant_b_staff) do
    tenant_b.users.create!(
      name: "記録スタッフB",
      email: "dashboard-staff-b-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  let!(:tenant_a_recent_reservation) do
    tenant_a.reservations.create!(
      client: tenant_a_client,
      service_date: Date.new(2026, 3, 1),
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled
    )
  end

  let!(:tenant_a_old_reservation) do
    tenant_a.reservations.create!(
      client: tenant_a_client,
      service_date: Date.new(2026, 3, 1),
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled
    )
  end

  let!(:tenant_a_blank_reservation) do
    tenant_a.reservations.create!(
      client: tenant_a_client,
      service_date: Date.new(2026, 3, 1),
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled
    )
  end

  let!(:tenant_a_stale_reservation) do
    tenant_a.reservations.create!(
      client: tenant_a_client,
      service_date: Date.new(2026, 2, 28),
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled
    )
  end

  let!(:tenant_b_reservation) do
    tenant_b.reservations.create!(
      client: tenant_b_client,
      service_date: Date.new(2026, 3, 1),
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled
    )
  end

  around do |example|
    travel_to(Time.zone.parse("2026-03-01 12:00:00 +0900")) { example.run }
  end

  def create_care_record!(tenant:, reservation:, user:, handoff_note:, created_at:)
    care_record = tenant.care_records.create!(
      tenant: tenant,
      reservation: reservation,
      recorded_by_user: user,
      handoff_note: handoff_note
    )
    care_record.update_columns(created_at: created_at, updated_at: created_at) # rubocop:disable Rails/SkipsModelValidations
    care_record
  end

  describe "GET /api/v1/dashboard/handoffs" do
    it "returns 401 without token" do
      get "/api/v1/dashboard/handoffs"

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end

    it "returns 403 without today_board:read permission" do
      get "/api/v1/dashboard/handoffs", headers: auth_headers_for(no_access_user)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("forbidden")
    end

    it "returns tenant-scoped handoffs sorted by created_at desc with is_new flag" do
      recent = create_care_record!(
        tenant: tenant_a,
        reservation: tenant_a_recent_reservation,
        user: tenant_a_staff,
        handoff_note: "食後の服薬は完了、歩行時の見守り継続",
        created_at: 2.hours.ago
      )
      old = create_care_record!(
        tenant: tenant_a,
        reservation: tenant_a_old_reservation,
        user: tenant_a_staff,
        handoff_note: "午後レク時に軽い疲労訴えあり",
        created_at: 7.hours.ago
      )
      create_care_record!(
        tenant: tenant_a,
        reservation: tenant_a_blank_reservation,
        user: tenant_a_staff,
        handoff_note: "   ",
        created_at: 1.hour.ago
      )
      create_care_record!(
        tenant: tenant_a,
        reservation: tenant_a_stale_reservation,
        user: tenant_a_staff,
        handoff_note: "24時間より前の申し送り",
        created_at: 26.hours.ago
      )
      create_care_record!(
        tenant: tenant_b,
        reservation: tenant_b_reservation,
        user: tenant_b_staff,
        handoff_note: "他テナントメモ",
        created_at: 1.hour.ago
      )

      get "/api/v1/dashboard/handoffs", headers: auth_headers_for(reader_user)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("meta", "total")).to eq(2)
      expect(json_body.dig("meta", "window_hours")).to eq(24)
      expect(json_body.dig("meta", "new_threshold_hours")).to eq(6)

      handoffs = json_body.fetch("handoffs")
      expect(handoffs.map { |handoff| handoff.fetch("care_record_id") }).to eq([ recent.id, old.id ])

      first = handoffs.first
      expect(first.fetch("client_name")).to eq(tenant_a_client.name)
      expect(first.fetch("recorded_by_user_name")).to eq(tenant_a_staff.name)
      expect(first.fetch("handoff_note")).to eq("食後の服薬は完了、歩行時の見守り継続")
      expect(first.fetch("is_new")).to eq(true)

      second = handoffs.second
      expect(second.fetch("is_new")).to eq(false)
      expect(second.fetch("client_id")).to eq(tenant_a_client.id)
      expect(second.fetch("reservation_id")).to eq(tenant_a_old_reservation.id)
    end
  end
end
