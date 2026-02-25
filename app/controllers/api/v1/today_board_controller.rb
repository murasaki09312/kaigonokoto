module Api
  module V1
    class TodayBoardController < ApplicationController
      def index
        authorize :today_board, :index?, policy_class: TodayBoardPolicy
        target_date = parse_date_param(params[:date])
        return if performed?

        result = TodayOperationsQuery.new(tenant: current_tenant, date: target_date).call

        render json: {
          items: result.reservations.map do |reservation|
            today_board_item_response(reservation, result.line_notifications_by_care_record_id)
          end,
          meta: result.meta
        }, status: :ok
      end

      private

      def parse_date_param(raw_date)
        return Date.current if raw_date.blank?

        Date.iso8601(raw_date.to_s)
      rescue ArgumentError
        render_error("bad_request", "date must be ISO date (YYYY-MM-DD)", :bad_request)
        nil
      end

      def today_board_item_response(reservation, line_notifications_by_care_record_id)
        line_summary = client_line_summary(reservation.client)
        line_notification = line_notifications_by_care_record_id[reservation.care_record&.id]

        {
          reservation: reservation_response(reservation),
          attendance: reservation.attendance ? attendance_response(reservation.attendance) : nil,
          care_record: reservation.care_record ? care_record_response(reservation.care_record) : nil,
          line_notification: line_notification_response(line_notification),
          line_notification_available: line_summary.fetch(:line_notification_available),
          line_linked_family_count: line_summary.fetch(:line_linked_family_count),
          line_enabled_family_count: line_summary.fetch(:line_enabled_family_count)
        }
      end
    end
  end
end
