class CareRecordHandoffEventPublisher
  EVENT_NAME = "care_record.handoff_note_changed".freeze

  def self.build_payload(tenant:, reservation:, care_record:, actor_user:, handoff_note:, event_id: SecureRandom.uuid, occurred_at: Time.current)
    {
      event_id: event_id,
      tenant_id: tenant.id,
      client_id: reservation.client_id,
      reservation_id: reservation.id,
      care_record_id: care_record.id,
      actor_user_id: actor_user&.id,
      handoff_note: handoff_note,
      occurred_at: occurred_at.iso8601
    }
  end

  def self.publish!(payload:)
    ActiveSupport::Notifications.instrument(EVENT_NAME, payload.deep_symbolize_keys)
  end
end
