require "bigdecimal"

module Billing
  class CopaymentBreakdownService
    Result = Struct.new(
      :copayment_rate,
      :insurance_claim_yen,
      :insured_copayment_yen,
      :excess_copayment_yen,
      :final_copayment_yen,
      keyword_init: true
    )

    DEFAULT_COPAYMENT_RATE = BigDecimal("0.1")
    ALLOWED_COPAYMENT_RATES = [
      BigDecimal("0.1"),
      BigDecimal("0.2"),
      BigDecimal("0.3")
    ].freeze

    def initialize(rounding_strategy: Billing::RoundingStrategy::Truncate.new)
      unless rounding_strategy.respond_to?(:apply)
        raise ArgumentError, "rounding_strategy must respond to #apply"
      end

      @rounding_strategy = rounding_strategy
    end

    def calculate(total_cost_yen:, excess_copayment_yen: Billing::YenAmount.new(0), copayment_rate: nil)
      total_cost = coerce_yen(total_cost_yen, "total_cost_yen")
      excess_cost = coerce_yen(excess_copayment_yen, "excess_copayment_yen")
      rate = coerce_copayment_rate(copayment_rate)

      insurance_claim_yen = Billing::YenAmount.new(
        @rounding_strategy.apply(
          BigDecimal(total_cost.value.to_s) * (BigDecimal("1") - rate)
        )
      )

      insured_copayment_yen = total_cost - insurance_claim_yen
      final_copayment_yen = insured_copayment_yen + excess_cost

      Result.new(
        copayment_rate: rate,
        insurance_claim_yen: insurance_claim_yen,
        insured_copayment_yen: insured_copayment_yen,
        excess_copayment_yen: excess_cost,
        final_copayment_yen: final_copayment_yen
      )
    end

    private

    def coerce_yen(value, name)
      return value if value.is_a?(Billing::YenAmount)

      raise ArgumentError, "#{name} must be Billing::YenAmount"
    end

    def coerce_copayment_rate(value)
      rate = case value
      when nil
        DEFAULT_COPAYMENT_RATE
      when BigDecimal
        value
      when Numeric, String
        begin
          BigDecimal(value.to_s)
        rescue ArgumentError
          nil
        end
      else
        nil
      end

      return rate if rate && ALLOWED_COPAYMENT_RATES.any? { |allowed| allowed == rate }

      raise ArgumentError, "copayment_rate must be one of 0.1, 0.2, 0.3"
    end
  end
end
