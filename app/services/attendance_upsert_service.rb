class AttendanceUpsertService
  def initialize(tenant:, reservation:, attributes:)
    @tenant = tenant
    @reservation = reservation
    @attributes = attributes
  end

  def call
    attendance = @reservation.attendance || @tenant.attendances.new(reservation: @reservation)
    attendance.assign_attributes(@attributes)
    attendance.save!
    attendance
  end
end
