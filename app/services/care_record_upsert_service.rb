class CareRecordUpsertService
  MAX_RETRIES = 1

  def initialize(tenant:, reservation:, actor_user:, attributes:, send_line_notification: false)
    @tenant = tenant
    @reservation = reservation
    @actor_user = actor_user
    @attributes = attributes
    @send_line_notification = ActiveModel::Type::Boolean.new.cast(send_line_notification)
  end

  def call
    retries = 0

    begin
      care_record = nil
      event_payload = nil

      @reservation.with_lock do
        care_record = @tenant.care_records.find_or_initialize_by(reservation_id: @reservation.id)

        care_record.assign_attributes(@attributes)
        care_record.recorded_by_user = @actor_user
        care_record.save!

        after_handoff_note = normalized_note(care_record.handoff_note)
        if should_publish_handoff_event?(handoff_note: after_handoff_note)
          event_payload = CareRecordHandoffEventPublisher.build_payload(
            tenant: @tenant,
            reservation: @reservation,
            care_record: care_record,
            actor_user: @actor_user,
            handoff_note: after_handoff_note
          )
        end
      end

      publish_handoff_event(event_payload) if event_payload.present?
      care_record
    rescue ActiveRecord::RecordNotUnique
      retries += 1
      raise if retries > MAX_RETRIES

      @reservation.reload
      retry
    end
  end

  private

  def publish_handoff_event(event_payload)
    CareRecordHandoffEventPublisher.publish!(payload: event_payload)
  rescue StandardError => error
    report_notification_error(error, event_payload, stage: "event_publish")
    enqueue_notification_fallback(event_payload)
  end

  def enqueue_notification_fallback(event_payload)
    NotifyFamilyByLineJob.perform_later(event_payload)
  rescue StandardError => error
    report_notification_error(error, event_payload, stage: "fallback_enqueue")
  end

  def report_notification_error(error, event_payload, stage:)
    context = {
      service: self.class.name,
      stage: stage,
      event_name: CareRecordHandoffEventPublisher::EVENT_NAME,
      event_id: event_payload[:event_id],
      tenant_id: event_payload[:tenant_id],
      reservation_id: event_payload[:reservation_id],
      care_record_id: event_payload[:care_record_id]
    }

    if Rails.respond_to?(:error) && Rails.error.respond_to?(:report)
      Rails.error.report(error, handled: true, severity: :warning, context: context)
    end

    Rails.logger.error(
      "[#{self.class.name}] Notification dispatch failed stage=#{stage} "\
      "event_id=#{event_payload[:event_id]} error_class=#{error.class} error_message=#{error.message}"
    )
  end

  def should_publish_handoff_event?(handoff_note:)
    @send_line_notification && handoff_note.present?
  end

  def normalized_note(note)
    note.to_s.strip.presence
  end
end
