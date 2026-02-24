class CareRecordUpsertService
  def initialize(tenant:, reservation:, actor_user:, attributes:)
    @tenant = tenant
    @reservation = reservation
    @actor_user = actor_user
    @attributes = attributes
  end

  def call
    care_record = @reservation.care_record || @tenant.care_records.new(reservation: @reservation)
    care_record.assign_attributes(@attributes)
    care_record.recorded_by_user = @actor_user
    care_record.save!
    care_record
  end
end
