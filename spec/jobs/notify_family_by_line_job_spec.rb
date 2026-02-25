require "rails_helper"

RSpec.describe NotifyFamilyByLineJob, type: :job do
  let!(:tenant) { Tenant.create!(name: "Tenant Job", slug: "tenant-job-#{SecureRandom.hex(4)}") }

  let!(:client) do
    tenant.clients.create!(
      name: "通知テスト 利用者",
      kana: "ツウチテスト リヨウシャ",
      status: :active
    )
  end

  let!(:reservation) do
    tenant.reservations.create!(
      client: client,
      service_date: Date.new(2026, 3, 1),
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled
    )
  end

  let!(:care_record) do
    tenant.care_records.create!(
      reservation: reservation,
      care_note: "テスト記録",
      handoff_note: "家族通知対象"
    )
  end

  let!(:family_member) do
    tenant.family_members.create!(
      client: client,
      name: "通知先 家族",
      relationship: "長女",
      line_user_id: "U1234567890",
      line_enabled: true,
      active: true,
      primary_contact: true
    )
  end

  let(:event_payload) do
    {
      event_id: SecureRandom.uuid,
      tenant_id: tenant.id,
      client_id: client.id,
      reservation_id: reservation.id,
      care_record_id: care_record.id,
      actor_user_id: nil,
      handoff_note: "家族通知対象",
      occurred_at: Time.current.iso8601
    }
  end

  it "sends LINE message and records sent log" do
    line_client = instance_double(LineMessagingClient)
    allow(LineMessagingClient).to receive(:new).and_return(line_client)
    allow(line_client).to receive(:push_message).and_return(
      {
        "sentMessages" => [ { "id" => "line-message-001" } ]
      }
    )

    described_class.perform_now(event_payload)

    expect(line_client).to have_received(:push_message).with(
      line_user_id: family_member.line_user_id,
      message: include("家族通知対象")
    )

    log = tenant.notification_logs.find_by!(family_member_id: family_member.id)
    expect(log.status).to eq("sent")
    expect(log.channel).to eq("line")
    expect(log.provider_message_id).to eq("line-message-001")
  end

  it "records failed log when LINE API raises an error" do
    line_client = instance_double(LineMessagingClient)
    allow(LineMessagingClient).to receive(:new).and_return(line_client)
    allow(line_client).to receive(:push_message).and_raise(
      LineMessagingClient::Error.new("LINE gateway error", error_code: "line_api_error")
    )

    described_class.perform_now(event_payload)

    log = tenant.notification_logs.find_by!(family_member_id: family_member.id)
    expect(log.status).to eq("failed")
    expect(log.error_code).to eq("line_api_error")
    expect(log.error_message).to eq("LINE gateway error")
  end

  it "is idempotent for the same event_id and recipient" do
    line_client = instance_double(LineMessagingClient)
    allow(LineMessagingClient).to receive(:new).and_return(line_client)
    allow(line_client).to receive(:push_message).and_return({})

    2.times { described_class.perform_now(event_payload) }

    expect(line_client).to have_received(:push_message).once
    expect(tenant.notification_logs.where(family_member_id: family_member.id).count).to eq(1)
  end

  it "creates skipped log when no LINE-connected family member is present" do
    family_member.update!(line_enabled: false, line_user_id: nil)
    line_client = instance_double(LineMessagingClient)
    allow(LineMessagingClient).to receive(:new).and_return(line_client)
    allow(line_client).to receive(:push_message)

    described_class.perform_now(event_payload)

    expect(line_client).not_to have_received(:push_message)
    log = tenant.notification_logs.find_by!(family_member_id: nil)
    expect(log.status).to eq("skipped")
    expect(log.error_code).to eq("line_recipient_not_found")
  end
end
