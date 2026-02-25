class CareRecordHandoffEventPublisher
  EVENT_NAME = "care_record.handoff_note_changed".freeze

  def self.publish!(tenant:, reservation:, care_record:, actor_user:, handoff_note:)
    ActiveSupport::Notifications.instrument(
      EVENT_NAME,
      {
        event_id: SecureRandom.uuid,
        tenant_id: tenant.id,
        client_id: reservation.client_id,
        reservation_id: reservation.id,
        care_record_id: care_record.id,
        actor_user_id: actor_user&.id,
        handoff_note: handoff_note,
        occurred_at: Time.current.iso8601
      }
    )
  end
end
