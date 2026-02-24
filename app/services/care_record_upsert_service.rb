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
      @reservation.with_lock do
        care_record = @tenant.care_records.find_or_initialize_by(reservation_id: @reservation.id)
        care_record.assign_attributes(@attributes)
        care_record.recorded_by_user = @actor_user
        care_record.save!
        care_record
      end
    rescue ActiveRecord::RecordNotUnique
      retries += 1
      raise if retries > MAX_RETRIES

      @reservation.reload
      retry
    end
  end
end
