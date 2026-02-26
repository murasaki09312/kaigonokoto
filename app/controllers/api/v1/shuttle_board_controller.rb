module Api
  module V1
    class ShuttleBoardController < ApplicationController
      def index
        shuttle_board_policy = ShuttleBoardPolicy.new(current_user, :shuttle_board)
        authorize :shuttle_board, :index?, policy_class: ShuttleBoardPolicy
        target_date = parse_date_param(params[:date])
        return if performed?

        result = ShuttleBoardQuery.new(tenant: current_tenant, date: target_date).call

        render json: {
          items: result.reservations.map { |reservation| shuttle_board_item_response(reservation) },
          meta: result.meta.merge(
            capabilities: {
              can_update_leg: shuttle_board_policy.update_leg?,
              can_manage_schedule: shuttle_board_policy.manage_schedule?
            }
          )
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

      def shuttle_board_item_response(reservation)
        operation = reservation.shuttle_operation

        {
          reservation: reservation_response(reservation),
          shuttle_operation: {
            id: operation&.id,
            tenant_id: reservation.tenant_id,
            reservation_id: reservation.id,
            client_id: reservation.client_id,
            service_date: reservation.service_date,
            requires_pickup: operation&.requires_pickup != false,
            requires_dropoff: operation&.requires_dropoff != false,
            pickup_leg: shuttle_leg_response(operation&.pickup_leg, default_direction: "pickup"),
            dropoff_leg: shuttle_leg_response(operation&.dropoff_leg, default_direction: "dropoff"),
            created_at: operation&.created_at,
            updated_at: operation&.updated_at
          }
        }
      end
    end
  end
end
