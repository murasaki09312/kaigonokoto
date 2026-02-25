require "rails_helper"

RSpec.describe CareRecordUpsertService, type: :service do
  let!(:tenant) { Tenant.create!(name: "Tenant Service", slug: "tenant-service-#{SecureRandom.hex(4)}") }

  let!(:manager_role) do
    role = Role.find_or_create_by!(name: "care_record_service_manager")
    role.permissions = [ Permission.find_or_create_by!(key: "care_records:manage") ]
    role
  end

  let!(:actor_user) do
    tenant.users.create!(
      name: "Care Manager",
      email: "care-manager-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ manager_role ]
    )
  end

  let!(:client) do
    tenant.clients.create!(
      name: "サービス 利用者",
      kana: "サービス リヨウシャ",
      status: :active
    )
  end

  let!(:reservation) do
    tenant.reservations.create!(
      client: client,
      service_date: Date.new(2026, 2, 27),
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled
    )
  end

  it "publishes a handoff_note event when a note is newly added" do
    captured_payloads = capture_handoff_events do
      described_class.new(
        tenant: tenant,
        reservation: reservation,
        actor_user: actor_user,
        attributes: {
          care_note: "午前は体操",
          handoff_note: "食後の服薬確認済み"
        }
      ).call
    end

    expect(captured_payloads.size).to eq(1)
    payload = captured_payloads.first
    expect(payload[:tenant_id]).to eq(tenant.id)
    expect(payload[:client_id]).to eq(client.id)
    expect(payload[:reservation_id]).to eq(reservation.id)
    expect(payload[:care_record_id]).to be_present
    expect(payload[:actor_user_id]).to eq(actor_user.id)
    expect(payload[:handoff_note]).to eq("食後の服薬確認済み")
    expect(payload[:event_id]).to be_present
  end

  it "does not publish an event when handoff_note is unchanged" do
    tenant.care_records.create!(
      reservation: reservation,
      recorded_by_user: actor_user,
      handoff_note: "既存メモ",
      care_note: "初回"
    )

    captured_payloads = capture_handoff_events do
      described_class.new(
        tenant: tenant,
        reservation: reservation,
        actor_user: actor_user,
        attributes: {
          care_note: "更新のみ",
          handoff_note: "既存メモ"
        }
      ).call
    end

    expect(captured_payloads).to eq([])
  end

  it "does not publish an event when handoff_note is blank" do
    captured_payloads = capture_handoff_events do
      described_class.new(
        tenant: tenant,
        reservation: reservation,
        actor_user: actor_user,
        attributes: {
          care_note: "メモのみ更新"
        }
      ).call
    end

    expect(captured_payloads).to eq([])
  end

  private

  def capture_handoff_events
    events = []
    subscription = ActiveSupport::Notifications.subscribe(CareRecordHandoffEventPublisher::EVENT_NAME) do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      events << event.payload.deep_symbolize_keys
    end

    yield
    events
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end
end
