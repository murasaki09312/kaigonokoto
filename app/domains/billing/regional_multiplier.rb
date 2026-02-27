require "bigdecimal"

module Billing
  class RegionalMultiplier
    attr_reader :rate, :rounding_strategy

    def initialize(rate, rounding_strategy: Billing::RoundingStrategy::Truncate.new)
      @rate = coerce_rate(rate)
      if @rate.negative?
        raise ArgumentError, "regional multiplier must be non-negative"
      end
      unless rounding_strategy.respond_to?(:apply)
        raise ArgumentError, "rounding strategy must respond to #apply"
      end

      @rounding_strategy = rounding_strategy
      freeze
    end

    def calculate_yen(unit:)
      unless unit.is_a?(Billing::CareServiceUnit)
        raise TypeError, "unit must be Billing::CareServiceUnit"
      end

      raw_amount = unit.value * @rate
      Billing::YenAmount.new(@rounding_strategy.apply(raw_amount))
    end

    private

    def coerce_rate(rate)
      case rate
      when BigDecimal
        rate
      when Numeric, String
        BigDecimal(rate.to_s)
      else
        raise ArgumentError, "regional multiplier must be BigDecimal, Numeric, or String"
      end
    rescue ArgumentError
      raise ArgumentError, "regional multiplier must be BigDecimal, Numeric, or String"
    end
  end
end
