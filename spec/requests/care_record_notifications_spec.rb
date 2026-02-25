require "rails_helper"

RSpec.describe "Care record notifications", type: :request do
  include ActiveJob::TestHelper

  let!(:care_records_manage) { Permission.find_or_create_by!(key: "care_records:manage") }

  let!(:manager_role) do
    role = Role.find_or_create_by!(name: "care_record_notifications_manager")
    role.permissions = [ care_records_manage ]
    role
  end

  let!(:tenant) { Tenant.create!(name: "Tenant Notify", slug: "tenant-notify-#{SecureRandom.hex(4)}") }

  let!(:user) do
    tenant.users.create!(
      name: "Notifier",
      email: "notify-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ manager_role ]
    )
  end

  let!(:client) do
    tenant.clients.create!(
      name: "通知 利用者",
      kana: "ツウチ リヨウシャ",
      status: :active
    )
  end

  let!(:reservation) do
    tenant.reservations.create!(
      client: client,
      service_date: Date.new(2026, 2, 28),
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled
    )
  end

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end

  it "enqueues NotifyFamilyByLineJob when handoff_note is added and send_line_notification is true" do
    expect do
      put "/api/v1/reservations/#{reservation.id}/care_record", params: {
        handoff_note: "家族へ服薬状況を共有",
        send_line_notification: true
      }, as: :json, headers: auth_headers_for(user)
    end.to have_enqueued_job(NotifyFamilyByLineJob)

    expect(response).to have_http_status(:ok)
  end

  it "does not enqueue NotifyFamilyByLineJob when send_line_notification is false" do
    expect do
      put "/api/v1/reservations/#{reservation.id}/care_record", params: {
        handoff_note: "送信しない申し送り",
        send_line_notification: false
      }, as: :json, headers: auth_headers_for(user)
    end.not_to have_enqueued_job(NotifyFamilyByLineJob)

    expect(response).to have_http_status(:ok)
  end

  it "does not enqueue when handoff_note is blank even if send_line_notification is true" do
    expect do
      put "/api/v1/reservations/#{reservation.id}/care_record", params: {
        care_note: "日中は安定",
        send_line_notification: true
      }, as: :json, headers: auth_headers_for(user)
    end.not_to have_enqueued_job(NotifyFamilyByLineJob)

    expect(response).to have_http_status(:ok)
  end

  it "enqueues when handoff_note is unchanged but send_line_notification is true" do
    put "/api/v1/reservations/#{reservation.id}/care_record", params: {
      handoff_note: "変化なし",
      send_line_notification: false
    }, as: :json, headers: auth_headers_for(user)

    clear_enqueued_jobs

    expect do
      put "/api/v1/reservations/#{reservation.id}/care_record", params: {
        handoff_note: "変化なし",
        care_note: "更新のみ",
        send_line_notification: true
      }, as: :json, headers: auth_headers_for(user)
    end.to have_enqueued_job(NotifyFamilyByLineJob)

    expect(response).to have_http_status(:ok)
  end

  it "returns 200 and keeps care_record persisted when event publish fails" do
    allow(CareRecordHandoffEventPublisher).to receive(:publish!).and_raise(StandardError, "publisher failure")
    allow(NotifyFamilyByLineJob).to receive(:perform_later)

    put "/api/v1/reservations/#{reservation.id}/care_record", params: {
      handoff_note: "通知失敗でも保存される",
      send_line_notification: true
    }, as: :json, headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    expect(reservation.reload.care_record&.handoff_note).to eq("通知失敗でも保存される")
    expect(NotifyFamilyByLineJob).to have_received(:perform_later).with(
      hash_including(
        :event_id,
        tenant_id: tenant.id,
        reservation_id: reservation.id,
        care_record_id: reservation.reload.care_record&.id
      )
    )
  end

  it "returns 200 when both publish and fallback enqueue fail" do
    allow(CareRecordHandoffEventPublisher).to receive(:publish!).and_raise(StandardError, "publisher failure")
    allow(NotifyFamilyByLineJob).to receive(:perform_later).and_raise(StandardError, "queue down")

    put "/api/v1/reservations/#{reservation.id}/care_record", params: {
      handoff_note: "フォールバックも失敗",
      send_line_notification: true
    }, as: :json, headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    expect(reservation.reload.care_record&.handoff_note).to eq("フォールバックも失敗")
  end
end
