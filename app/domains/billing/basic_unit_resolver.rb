module Billing
  class BasicUnitResolver
    DURATION_H7_TO_H8 = :h7_to_h8
    FACILITY_SCALES = %w[normal large_1 large_2].freeze

    UNIT_TABLE = {
      normal: {
        DURATION_H7_TO_H8 => {
          1 => 658,
          2 => 777,
          3 => 861,
          4 => 980,
          5 => 1093
        }
      }
    }.freeze

    def self.supported_facility_scales
      FACILITY_SCALES
    end

    def self.supported_duration_categories
      [ DURATION_H7_TO_H8 ]
    end

    def resolve(care_level:, duration_category:, facility_scale:)
      level = coerce_care_level(care_level)
      duration = coerce_duration(duration_category)
      scale = coerce_scale(facility_scale)

      unit_value = UNIT_TABLE.dig(scale, duration, level)
      if unit_value.nil?
        raise ArgumentError, "unsupported combination: facility_scale=#{scale}, duration_category=#{duration}, care_level=#{level}"
      end

      Billing::CareServiceUnit.new(unit_value)
    end

    private

    def coerce_care_level(value)
      integer_value = Integer(value)
      if integer_value < 1 || integer_value > 5
        raise ArgumentError, "care_level must be within 1..5"
      end

      integer_value
    rescue ArgumentError, TypeError
      raise ArgumentError, "care_level must be within 1..5"
    end

    def coerce_duration(value)
      normalized = value.to_s.strip.to_sym
      if normalized == :"" || normalized == :"7h_to_8h"
        return DURATION_H7_TO_H8
      end

      if self.class.supported_duration_categories.include?(normalized)
        return normalized
      end

      raise ArgumentError, "unsupported duration_category: #{value}"
    end

    def coerce_scale(value)
      normalized = value.to_s.strip
      raise ArgumentError, "facility_scale is required" if normalized.blank?

      symbolized = normalized.to_sym
      if self.class.supported_facility_scales.include?(symbolized.to_s)
        return symbolized
      end

      raise ArgumentError, "unsupported facility_scale: #{value}"
    end
  end
end
