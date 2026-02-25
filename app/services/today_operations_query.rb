class TodayOperationsQuery
  Result = Struct.new(
    :reservations,
    :meta,
    :line_notifications_by_care_record_id,
    keyword_init: true
  )

  def initialize(tenant:, date:)
    @tenant = tenant
    @date = date
  end

  def call
    reservations = @tenant.reservations
      .where(service_date: @date)
      .includes({ client: :family_members }, :attendance, :care_record)
      .in_display_order

    attendance_counts = Attendance.statuses.keys.index_with { 0 }
    care_record_completed = 0

    reservations.each do |reservation|
      attendance_status = reservation.attendance&.status || "pending"
      attendance_counts[attendance_status] += 1 if attendance_counts.key?(attendance_status)
      care_record_completed += 1 if reservation.care_record.present?
    end

    line_notifications_by_care_record_id = build_line_notifications_by_care_record_id(reservations)

    Result.new(
      reservations: reservations,
      meta: {
        date: @date,
        total: reservations.size,
        attendance_counts: attendance_counts,
        care_record_completed: care_record_completed,
        care_record_pending: reservations.size - care_record_completed
      },
      line_notifications_by_care_record_id: line_notifications_by_care_record_id
    )
  end

  private

  def build_line_notifications_by_care_record_id(reservations)
    care_record_ids = reservations.filter_map { |reservation| reservation.care_record&.id }
    return {} if care_record_ids.empty?

    logs = @tenant.notification_logs
      .where(
        source_type: "CareRecord",
        source_id: care_record_ids,
        channel: NotificationLog.channels.fetch("line")
      )
      .order(source_id: :asc, created_at: :desc, id: :desc)

    logs.group_by(&:source_id).transform_values { |grouped_logs| summarize_line_notifications(grouped_logs) }
  end

  def summarize_line_notifications(logs)
    sent_count = logs.count(&:status_sent?)
    failed_logs = logs.select(&:status_failed?)
    queued_count = logs.count(&:status_queued?)
    skipped_count = logs.count(&:status_skipped?)

    status = if failed_logs.any?
      "failed"
    elsif queued_count.positive?
      "queued"
    elsif sent_count.positive?
      "sent"
    elsif skipped_count.positive?
      "skipped"
    else
      "unsent"
    end

    latest_failed_log = failed_logs.max_by(&:created_at)
    latest_log = logs.first

    {
      status: status,
      total_count: logs.size,
      sent_count: sent_count,
      failed_count: failed_logs.size,
      last_error_code: latest_failed_log&.error_code,
      last_error_message: latest_failed_log&.error_message,
      updated_at: latest_log&.updated_at
    }
  end
end
