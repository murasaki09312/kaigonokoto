class CareRecordUpsertService
  MAX_RETRIES = 1

  def initialize(tenant:, reservation:, actor_user:, attributes:)
    @tenant = tenant
    @reservation = reservation
    @actor_user = actor_user
    @attributes = attributes
  end

  def call
    retries = 0

    begin
      care_record = nil
      event_payload = nil

      @reservation.with_lock do
        care_record = @tenant.care_records.find_or_initialize_by(reservation_id: @reservation.id)
        before_handoff_note = normalized_note(care_record.handoff_note)

        care_record.assign_attributes(@attributes)
        care_record.recorded_by_user = @actor_user
        care_record.save!

        after_handoff_note = normalized_note(care_record.handoff_note)
        if handoff_note_changed?(before: before_handoff_note, after: after_handoff_note)
          event_payload = {
            tenant: @tenant,
            reservation: @reservation,
            care_record: care_record,
            actor_user: @actor_user,
            handoff_note: after_handoff_note
          }
        end
      end

      CareRecordHandoffEventPublisher.publish!(**event_payload) if event_payload.present?
      care_record
    rescue ActiveRecord::RecordNotUnique
      retries += 1
      raise if retries > MAX_RETRIES

      @reservation.reload
      retry
    end
  end

  private

  def handoff_note_changed?(before:, after:)
    after.present? && before != after
  end

  def normalized_note(note)
    note.to_s.strip.presence
  end
end
