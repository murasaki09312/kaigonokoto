require "bigdecimal"

module Billing
  class ImprovementAdditionCalculator
    def initialize(rounding_strategy: Billing::RoundingStrategy::HalfUp.new)
      unless rounding_strategy.respond_to?(:apply)
        raise ArgumentError, "rounding_strategy must respond to #apply"
      end

      @rounding_strategy = rounding_strategy
    end

    def calculate_units(insured_units:, rate:)
      units = coerce_units(insured_units)
      rate_decimal = coerce_rate(rate)
      raw_units = BigDecimal(units.value.to_s) * rate_decimal

      Billing::CareServiceUnit.new(@rounding_strategy.apply(raw_units))
    end

    private

    def coerce_units(value)
      return value if value.is_a?(Billing::CareServiceUnit)

      raise ArgumentError, "insured_units must be Billing::CareServiceUnit"
    end

    def coerce_rate(value)
      rate = case value
      when BigDecimal
        value
      when Numeric, String
        begin
          BigDecimal(value.to_s)
        rescue ArgumentError
          raise ArgumentError, "rate must be BigDecimal, Numeric, or String"
        end
      else
        raise ArgumentError, "rate must be BigDecimal, Numeric, or String"
      end

      if rate.negative? || rate > BigDecimal("1")
        raise ArgumentError, "rate must be between 0 and 1"
      end

      rate
    end
  end
end
