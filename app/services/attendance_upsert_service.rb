class AttendanceUpsertService
  MAX_RETRIES = 1

  def initialize(tenant:, reservation:, attributes:)
    @tenant = tenant
    @reservation = reservation
    @attributes = attributes
  end

  def call
    retries = 0

    begin
      @reservation.with_lock do
        attendance = @tenant.attendances.find_or_initialize_by(reservation_id: @reservation.id)
        attendance.assign_attributes(@attributes)
        attendance.save!
        attendance
      end
    rescue ActiveRecord::RecordNotUnique
      retries += 1
      raise if retries > MAX_RETRIES

      @reservation.reload
      retry
    end
  end
end
