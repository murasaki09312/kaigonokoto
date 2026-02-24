module Api
  module V1
    class AttendancesController < ApplicationController
      before_action :set_reservation

      def upsert
        authorize @reservation, :upsert?, policy_class: AttendancePolicy

        attendance = AttendanceUpsertService.new(
          tenant: current_tenant,
          reservation: @reservation,
          attributes: attendance_params.to_h
        ).call

        render json: { attendance: attendance_response(attendance) }, status: :ok
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

      def attendance_params
        params.permit(
          :status,
          :absence_reason,
          :contacted_at,
          :note
        )
      end
    end
  end
end
