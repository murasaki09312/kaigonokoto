module Api
  module V1
    class FacilitySettingsController < ApplicationController
      def show
        authorize :facility_setting, :show?, policy_class: FacilitySettingPolicy

        render json: { facility_setting: facility_setting_response(current_tenant) }, status: :ok
      end

      def update
        authorize :facility_setting, :update?, policy_class: FacilitySettingPolicy
        attributes = facility_setting_params.to_h
        city_name = attributes.key?("city_name") ? attributes["city_name"] : current_tenant.city_name
        facility_scale = attributes.key?("facility_scale") ? attributes["facility_scale"] : current_tenant.facility_scale

        if invalid_city_name?(city_name)
          current_tenant.errors.add(:city_name, "is unsupported")
          return render_validation_error(current_tenant)
        end

        if invalid_facility_scale?(facility_scale)
          current_tenant.errors.add(:facility_scale, "is invalid")
          return render_validation_error(current_tenant)
        end

        if current_tenant.update(attributes)
          render json: { facility_setting: facility_setting_response(current_tenant) }, status: :ok
        else
          render_validation_error(current_tenant)
        end
      end

      private

      def facility_setting_params
        params.permit(:city_name, :facility_scale)
      end

      def invalid_facility_scale?(value)
        return false if value.nil?
        return false if value.blank?

        !Tenant.facility_scales.key?(value)
      end

      def invalid_city_name?(value)
        city_name = value.to_s.strip
        return true if city_name.blank?

        !Billing::AreaGradeResolver.supported_cities.include?(city_name)
      end

      def facility_setting_response(tenant)
        {
          tenant_id: tenant.id,
          city_name: tenant.city_name,
          facility_scale: tenant.facility_scale,
          city_options: Billing::AreaGradeResolver.supported_cities,
          facility_scale_options: Tenant.facility_scales.keys.map do |scale|
            {
              value: scale,
              label: facility_scale_label(scale)
            }
          end
        }
      end

      def facility_scale_label(scale)
        case scale
        when "normal" then "通常規模型"
        when "large_1" then "大規模型Ⅰ"
        when "large_2" then "大規模型Ⅱ"
        else scale
        end
      end
    end
  end
end
