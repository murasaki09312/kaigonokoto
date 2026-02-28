require "bigdecimal"

module Billing
  class InvoiceCalculationService
    Result = Struct.new(
      :total_cost_yen,
      :insurance_claim_yen,
      :insured_copayment_yen,
      :excess_copayment_yen,
      :final_copayment_yen,
      keyword_init: true
    )

    ALLOWED_COPAYMENT_RATES = [
      BigDecimal("0.1"),
      BigDecimal("0.2"),
      BigDecimal("0.3")
    ].freeze

    def initialize(insurance_rounding_strategy: Billing::RoundingStrategy::Truncate.new)
      unless insurance_rounding_strategy.respond_to?(:apply)
        raise ArgumentError, "insurance_rounding_strategy must respond to #apply"
      end

      @insurance_rounding_strategy = insurance_rounding_strategy
    end

    def calculate(
      insured_units:,
      self_pay_units:,
      improvement_addition_units: Billing::CareServiceUnit.new(0),
      regional_multiplier:,
      copayment_rate:
    )
      insured = coerce_units(insured_units, "insured_units")
      self_pay = coerce_units(self_pay_units, "self_pay_units")
      improvement = coerce_units(improvement_addition_units, "improvement_addition_units")
      multiplier = coerce_multiplier(regional_multiplier)
      rate = coerce_copayment_rate(copayment_rate)

      covered_units = insured + improvement
      total_cost_yen = multiplier.calculate_yen(unit: covered_units)

      insurance_claim_yen = Billing::YenAmount.new(
        @insurance_rounding_strategy.apply(
          BigDecimal(total_cost_yen.value.to_s) * (BigDecimal("1") - rate)
        )
      )

      insured_copayment_yen = total_cost_yen - insurance_claim_yen
      excess_copayment_yen = multiplier.calculate_yen(unit: self_pay)
      final_copayment_yen = insured_copayment_yen + excess_copayment_yen

      Result.new(
        total_cost_yen: total_cost_yen,
        insurance_claim_yen: insurance_claim_yen,
        insured_copayment_yen: insured_copayment_yen,
        excess_copayment_yen: excess_copayment_yen,
        final_copayment_yen: final_copayment_yen
      )
    end

    private

    def coerce_units(value, name)
      return value if value.is_a?(Billing::CareServiceUnit)

      raise ArgumentError, "#{name} must be Billing::CareServiceUnit"
    end

    def coerce_multiplier(value)
      return value if value.is_a?(Billing::RegionalMultiplier)

      raise ArgumentError, "regional_multiplier must be Billing::RegionalMultiplier"
    end

    def coerce_copayment_rate(value)
      rate = case value
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
