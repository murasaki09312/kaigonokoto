module Api
  module V1
    class CareRecordsController < ApplicationController
      before_action :set_reservation

      def upsert
        authorize @reservation, :upsert?, policy_class: CareRecordPolicy

        care_record = CareRecordUpsertService.new(
          tenant: current_tenant,
          reservation: @reservation,
          actor_user: current_user,
          attributes: care_record_params.to_h,
          send_line_notification: send_line_notification_param
        ).call

        render json: { care_record: care_record_response(care_record) }, status: :ok
      rescue ActiveRecord::RecordInvalid => exception
        render_validation_error(exception.record)
      rescue ActiveRecord::RecordNotUnique
        render_error("validation_error", "Concurrent write conflict. Please retry.", :unprocessable_entity)
      end

      private

      def set_reservation
        @reservation = current_tenant.reservations.find(params[:reservation_id])
      end

      def care_record_params
        params.permit(
          :body_temperature,
          :systolic_bp,
          :diastolic_bp,
          :pulse,
          :spo2,
          :care_note,
          :handoff_note
        )
      end

      def send_line_notification_param
        ActiveModel::Type::Boolean.new.cast(params[:send_line_notification])
      end
    end
  end
end
