module Api
  module V1
    class ShuttleLegsController < ApplicationController
      before_action :set_reservation

      def upsert
        authorize @reservation, :upsert?, policy_class: ShuttleLegPolicy

        leg = ShuttleLegUpsertService.new(
          tenant: current_tenant,
          reservation: @reservation,
          direction: params[:direction],
          actor_user: current_user,
          attributes: shuttle_leg_params.to_h
        ).call

        render json: { shuttle_leg: shuttle_leg_response(leg) }, status: :ok
      rescue ActiveRecord::RecordInvalid => exception
        render_validation_error(exception.record)
      rescue ActiveRecord::RecordNotUnique
        render_error("validation_error", "Concurrent write conflict. Please retry.", :unprocessable_entity)
      rescue ArgumentError
        render_error("validation_error", "status is invalid", :unprocessable_entity)
      end

      private

      def set_reservation
        @reservation = current_tenant.reservations.find(params[:reservation_id])
      end

      def shuttle_leg_params
        params.permit(
          :status,
          :planned_at,
          :actual_at,
          :note
        )
      end
    end
  end
end
