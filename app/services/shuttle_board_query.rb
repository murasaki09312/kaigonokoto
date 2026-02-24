class ShuttleBoardQuery
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
      .where.not(status: Reservation.statuses.fetch("cancelled"))
      .includes(:client, shuttle_operation: { shuttle_legs: :handled_by_user })
      .in_display_order

    pickup_counts = ShuttleLeg.statuses.keys.index_with { 0 }
    dropoff_counts = ShuttleLeg.statuses.keys.index_with { 0 }

    reservations.each do |reservation|
      operation = reservation.shuttle_operation
      pickup_status = operation&.pickup_leg&.status || "pending"
      dropoff_status = operation&.dropoff_leg&.status || "pending"

      pickup_counts[pickup_status] += 1 if pickup_counts.key?(pickup_status)
      dropoff_counts[dropoff_status] += 1 if dropoff_counts.key?(dropoff_status)
    end

    Result.new(
      reservations: reservations,
      meta: {
        date: @date,
        total: reservations.size,
        pickup_counts: pickup_counts,
        dropoff_counts: dropoff_counts
      }
    )
  end
end
