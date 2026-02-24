class TodayOperationsQuery
  Result = Struct.new(
    :reservations,
    :meta,
    keyword_init: true
  )

  def initialize(tenant:, date:)
    @tenant = tenant
    @date = date
  end

  def call
    reservations = @tenant.reservations
      .where(service_date: @date)
      .includes(:client, :attendance, :care_record)
      .in_display_order

    attendance_counts = Attendance.statuses.keys.index_with { 0 }
    care_record_completed = 0

    reservations.each do |reservation|
      attendance_status = reservation.attendance&.status || "pending"
      attendance_counts[attendance_status] += 1 if attendance_counts.key?(attendance_status)
      care_record_completed += 1 if reservation.care_record.present?
    end

    Result.new(
      reservations: reservations,
      meta: {
        date: @date,
        total: reservations.size,
        attendance_counts: attendance_counts,
        care_record_completed: care_record_completed,
        care_record_pending: reservations.size - care_record_completed
      }
    )
  end
end
