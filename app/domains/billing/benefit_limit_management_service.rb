module Billing
  class BenefitLimitManagementService
    Result = Struct.new(:insured_units, :self_pay_units, keyword_init: true)

    def split_units(monthly_total_units:, benefit_limit_units:)
      total = coerce_units(monthly_total_units, "monthly_total_units")
      limit = coerce_units(benefit_limit_units, "benefit_limit_units")

      insured_value = [ total.value, limit.value ].min
      insured_units = Billing::CareServiceUnit.new(insured_value)

      Result.new(
        insured_units: insured_units,
        self_pay_units: total - insured_units
      )
    end

    private

    def coerce_units(value, name)
      return value if value.is_a?(Billing::CareServiceUnit)

      raise ArgumentError, "#{name} must be Billing::CareServiceUnit"
    end
  end
end
