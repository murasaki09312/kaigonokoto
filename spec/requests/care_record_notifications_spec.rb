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

  it "enqueues NotifyFamilyByLineJob when handoff_note is added" do
    expect do
      put "/api/v1/reservations/#{reservation.id}/care_record", params: {
        handoff_note: "家族へ服薬状況を共有"
      }, as: :json, headers: auth_headers_for(user)
    end.to have_enqueued_job(NotifyFamilyByLineJob)

    expect(response).to have_http_status(:ok)
  end

  it "does not enqueue NotifyFamilyByLineJob when only care_note is updated" do
    expect do
      put "/api/v1/reservations/#{reservation.id}/care_record", params: {
        care_note: "日中は安定"
      }, as: :json, headers: auth_headers_for(user)
    end.not_to have_enqueued_job(NotifyFamilyByLineJob)

    expect(response).to have_http_status(:ok)
  end

  it "does not enqueue when handoff_note is unchanged" do
    put "/api/v1/reservations/#{reservation.id}/care_record", params: {
      handoff_note: "変化なし"
    }, as: :json, headers: auth_headers_for(user)

    clear_enqueued_jobs

    expect do
      put "/api/v1/reservations/#{reservation.id}/care_record", params: {
        handoff_note: "変化なし",
        care_note: "更新のみ"
      }, as: :json, headers: auth_headers_for(user)
    end.not_to have_enqueued_job(NotifyFamilyByLineJob)

    expect(response).to have_http_status(:ok)
  end
end
