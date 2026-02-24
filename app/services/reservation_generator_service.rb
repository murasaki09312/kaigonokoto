require "set"

class ReservationGeneratorService
  Result = Struct.new(
    :reservations,
    :capacity_skipped_dates,
    :existing_skipped_total,
    keyword_init: true
  )

  def initialize(tenant:, start_on:, end_on:, start_time: nil, end_time: nil, notes: nil, status: "scheduled", force: false)
    @tenant = tenant
    @start_on = start_on
    @end_on = end_on
    @start_time = start_time
    @end_time = end_time
    @notes = notes
    @status = status
    @force = force
  end

  def call
    reservations = []
    capacity_skipped_dates = Set.new
    existing_skipped_total = 0

    ActiveRecord::Base.transaction do
      each_service_date do |service_date|
        target_client_ids = contract_client_ids_for(service_date)
        next if target_client_ids.empty?

        with_capacity_lock!(service_date) do
          existing_client_ids = existing_reservation_client_ids_for(service_date, target_client_ids)
          existing_skipped_total += existing_client_ids.size

          pending_client_ids = target_client_ids - existing_client_ids
          next if pending_client_ids.empty?

          creatable_client_ids, skipped_by_capacity = split_creatable_client_ids(
            service_date: service_date,
            pending_client_ids: pending_client_ids
          )
          capacity_skipped_dates << service_date if skipped_by_capacity

          creatable_client_ids.each do |client_id|
            reservations << @tenant.reservations.create!(
              client_id: client_id,
              service_date: service_date,
              start_time: @start_time,
              end_time: @end_time,
              notes: @notes,
              status: @status
            )
          end
        end
      end
    end

    Result.new(
      reservations: reservations,
      capacity_skipped_dates: capacity_skipped_dates.to_a.sort.map(&:iso8601),
      existing_skipped_total: existing_skipped_total
    )
  end

  private

  def each_service_date(&block)
    (@start_on..@end_on).each(&block)
  end

  def contract_client_ids_for(service_date)
    @tenant.contracts
      .where("start_on <= ? AND COALESCE(end_on, ?) >= ?", service_date, Contract::OPEN_ENDED_DATE, service_date)
      .where("? = ANY(weekdays)", service_date.wday)
      .order(:client_id)
      .distinct
      .pluck(:client_id)
  end

  def existing_reservation_client_ids_for(service_date, target_client_ids)
    @tenant.reservations
      .where(service_date: service_date, client_id: target_client_ids)
      .pluck(:client_id)
      .uniq
  end

  def split_creatable_client_ids(service_date:, pending_client_ids:)
    return [ pending_client_ids, false ] if @force || @status.to_s != "scheduled"

    scheduled_count = @tenant.reservations.scheduled_on(service_date).count
    remaining_capacity = @tenant.capacity_per_day - scheduled_count

    return [ [], pending_client_ids.any? ] if remaining_capacity <= 0

    creatable_client_ids = pending_client_ids.first(remaining_capacity)
    skipped_by_capacity = pending_client_ids.size > creatable_client_ids.size

    [ creatable_client_ids, skipped_by_capacity ]
  end

  def with_capacity_lock!(service_date)
    lock_key = service_date.strftime("%Y%m%d").to_i
    ActiveRecord::Base.connection.execute(
      "SELECT pg_advisory_xact_lock(#{@tenant.id}, #{lock_key})"
    )

    yield
  end
end
