class ShuttleLegUpsertService
  MAX_RETRIES = 1

  def initialize(tenant:, reservation:, direction:, actor_user:, attributes:)
    @tenant = tenant
    @reservation = reservation
    @direction = direction.to_s
    @actor_user = actor_user
    @attributes = attributes
  end

  def call
    attempts = 0

    begin
      ActiveRecord::Base.transaction do
        @reservation.lock!

        operation = find_or_build_operation!
        leg = operation.shuttle_legs.find_or_initialize_by(direction: @direction)

        assign_leg_attributes!(leg)
        leg.save!
        leg
      end
    rescue ActiveRecord::RecordNotUnique
      attempts += 1
      raise if attempts > MAX_RETRIES

      retry
    end
  end

  private

  def find_or_build_operation!
    operation = @tenant.shuttle_operations.find_or_initialize_by(reservation: @reservation)
    operation.assign_attributes(
      client: @reservation.client,
      service_date: @reservation.service_date
    )
    operation.save! if operation.new_record? || operation.changed?
    operation
  end

  def assign_leg_attributes!(leg)
    attrs = normalized_attributes
    leg.assign_attributes(attrs)
    leg.tenant = @tenant
    leg.handled_by_user = @actor_user

    if should_auto_set_actual_at?(leg, attrs)
      leg.actual_at = Time.current
    end
  end

  def normalized_attributes
    attrs = @attributes.symbolize_keys.slice(:status, :planned_at, :actual_at, :note)

    if attrs.key?(:status)
      status = attrs[:status].to_s
      raise ArgumentError, "status is invalid" unless ShuttleLeg.statuses.key?(status)

      attrs[:status] = status
    end

    attrs
  end

  def should_auto_set_actual_at?(leg, attrs)
    return false if attrs.key?(:actual_at)
    return false if leg.actual_at.present?

    leg.status_boarded? || leg.status_alighted?
  end
end
