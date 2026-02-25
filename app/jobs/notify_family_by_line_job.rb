class NotifyFamilyByLineJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(payload)
    data = payload.deep_symbolize_keys
    tenant = Tenant.find(data.fetch(:tenant_id))
    client = tenant.clients.find(data.fetch(:client_id))
    reservation = tenant.reservations.find(data.fetch(:reservation_id))
    care_record = tenant.care_records.find(data.fetch(:care_record_id))
    handoff_note = data.fetch(:handoff_note).to_s.strip
    return if handoff_note.blank?

    recipients = tenant.family_members.line_recipients_for(client.id)
    if recipients.empty?
      create_skipped_log!(tenant: tenant, client: client, care_record: care_record, data: data, handoff_note: handoff_note)
      return
    end

    line_client = LineMessagingClient.new
    message_body = build_message_body(client: client, reservation: reservation, handoff_note: handoff_note)

    recipients.each do |family_member|
      deliver_to_family_member!(
        tenant: tenant,
        client: client,
        care_record: care_record,
        family_member: family_member,
        line_client: line_client,
        message_body: message_body,
        data: data
      )
    end
  end

  private

  def build_message_body(client:, reservation:, handoff_note:)
    "【#{client.name}さん 申し送り】#{reservation.service_date.strftime('%Y-%m-%d')} #{handoff_note}"
  end

  def deliver_to_family_member!(tenant:, client:, care_record:, family_member:, line_client:, message_body:, data:)
    log = tenant.notification_logs.find_or_initialize_by(
      idempotency_key: idempotency_key_for(event_id: data.fetch(:event_id), recipient_key: family_member.id)
    )
    return if log.status_sent?

    log.assign_attributes(
      client: client,
      family_member: family_member,
      event_name: CareRecordHandoffEventPublisher::EVENT_NAME,
      source_type: "CareRecord",
      source_id: care_record.id,
      channel: :line,
      status: :queued,
      message_body: message_body,
      metadata: build_metadata(data)
    )
    log.error_code = nil
    log.error_message = nil
    log.save!

    response = line_client.push_message(line_user_id: family_member.line_user_id, message: message_body)
    log.update!(
      status: :sent,
      provider_message_id: extract_provider_message_id(response),
      error_code: nil,
      error_message: nil
    )
  rescue LineMessagingClient::Error => error
    log&.update!(
      status: :failed,
      error_code: error.error_code || "line_request_error",
      error_message: error.message
    )
  rescue StandardError => error
    log&.update!(
      status: :failed,
      error_code: error.class.name,
      error_message: error.message
    )
  end

  def create_skipped_log!(tenant:, client:, care_record:, data:, handoff_note:)
    log = tenant.notification_logs.find_or_initialize_by(
      idempotency_key: idempotency_key_for(event_id: data.fetch(:event_id), recipient_key: "no_recipient")
    )
    return if log.status_sent? || log.status_skipped?

    log.assign_attributes(
      client: client,
      family_member: nil,
      event_name: CareRecordHandoffEventPublisher::EVENT_NAME,
      source_type: "CareRecord",
      source_id: care_record.id,
      channel: :line,
      status: :skipped,
      message_body: handoff_note,
      error_code: "line_recipient_not_found",
      error_message: "No active LINE-connected family members for this client",
      metadata: build_metadata(data)
    )
    log.save!
  end

  def idempotency_key_for(event_id:, recipient_key:)
    "#{event_id}:#{recipient_key}"
  end

  def build_metadata(data)
    {
      reservation_id: data[:reservation_id],
      actor_user_id: data[:actor_user_id],
      occurred_at: data[:occurred_at]
    }.compact
  end

  def extract_provider_message_id(response)
    return if response.blank?

    response = response.with_indifferent_access
    sent_messages = response[:sentMessages]
    return sent_messages.first["id"] if sent_messages.respond_to?(:first) && sent_messages.first.is_a?(Hash)

    response[:messageId].presence || response[:id].presence
  end
end
