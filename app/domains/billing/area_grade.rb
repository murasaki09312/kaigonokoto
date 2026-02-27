require "bigdecimal"

module Billing
  class AreaGrade
    UNIT_PRICES = {
      grade_1: BigDecimal("10.90")
    }.freeze

    attr_reader :code, :unit_price

    def initialize(code:)
      symbol_code = code.to_sym
      unit_price = UNIT_PRICES[symbol_code]
      raise ArgumentError, "unsupported area grade: #{code}" if unit_price.nil?

      @code = symbol_code
      @unit_price = unit_price
      freeze
    end

    def to_regional_multiplier(rounding_strategy: Billing::RoundingStrategy::Truncate.new)
      Billing::RegionalMultiplier.new(@unit_price, rounding_strategy: rounding_strategy)
    end
  end
end
