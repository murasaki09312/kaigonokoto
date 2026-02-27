module Dashboard
  class HandoffFeedQuery
    DEFAULT_WINDOW_HOURS = 24
    DEFAULT_NEW_THRESHOLD_HOURS = 6

    Result = Struct.new(:handoffs, :meta, keyword_init: true)

    def initialize(tenant:, now: Time.current, window_hours: DEFAULT_WINDOW_HOURS, new_threshold_hours: DEFAULT_NEW_THRESHOLD_HOURS)
      @tenant = tenant
      @now = now
      @window_hours = window_hours
      @new_threshold_hours = new_threshold_hours
    end

    def call
      care_records = handoff_scope

      Result.new(
        handoffs: care_records.map { |care_record| handoff_response(care_record) },
        meta: {
          total: care_records.size,
          window_hours: @window_hours,
          new_threshold_hours: @new_threshold_hours
        }
      )
    end

    private

    def handoff_scope
      @tenant.care_records
        .joins(reservation: :client)
        .includes(:recorded_by_user, reservation: :client)
        .where("care_records.created_at >= ?", @now - @window_hours.hours)
        .where("care_records.handoff_note IS NOT NULL AND btrim(care_records.handoff_note) <> ''")
        .order(created_at: :desc, id: :desc)
    end

    def handoff_response(care_record)
      {
        care_record_id: care_record.id,
        reservation_id: care_record.reservation_id,
        client_id: care_record.reservation.client_id,
        client_name: care_record.reservation.client.name,
        recorded_by_user_id: care_record.recorded_by_user_id,
        recorded_by_user_name: care_record.recorded_by_user&.name,
        handoff_note: care_record.handoff_note,
        created_at: care_record.created_at,
        is_new: care_record.created_at >= (@now - @new_threshold_hours.hours)
      }
    end
  end
end
