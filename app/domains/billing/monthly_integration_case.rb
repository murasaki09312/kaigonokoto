module Billing
  class MonthlyIntegrationCase
    CARE_LEVEL = "要介護1".freeze
    BENEFIT_LIMIT_UNITS = 16_765
    BASE_UNITS = 658
    MONTHLY_USE_COUNT = 22
    IMPROVEMENT_RATE = "0.245".freeze

    EXPECTED = {
      daily_total_units: 774,
      monthly_total_units: 17_028,
      insured_units: 16_765,
      self_pay_units: 263,
      improvement_units: 4_107
    }.freeze

    Result = Struct.new(:scenario, :calculated, :expected, :matches_expected, keyword_init: true)

    def call
      daily_record = Billing::DailyServiceRecord.new(
        base_units: Billing::CareServiceUnit.new(BASE_UNITS),
        additions: [ bathing_addition, training_addition ]
      )
      daily_total_units = daily_record.total_units

      monthly_total_units = MONTHLY_USE_COUNT.times.reduce(Billing::CareServiceUnit.new(0)) do |sum, _|
        sum + daily_total_units
      end

      split_result = Billing::BenefitLimitManagementService.new.split_units(
        monthly_total_units: monthly_total_units,
        benefit_limit_units: Billing::CareServiceUnit.new(BENEFIT_LIMIT_UNITS)
      )

      improvement_units = Billing::ImprovementAdditionCalculator.new.calculate_units(
        insured_units: split_result.insured_units,
        rate: IMPROVEMENT_RATE
      )

      calculated = {
        daily_total_units: daily_total_units.value,
        monthly_total_units: monthly_total_units.value,
        insured_units: split_result.insured_units.value,
        self_pay_units: split_result.self_pay_units.value,
        improvement_units: improvement_units.value
      }

      Result.new(
        scenario: scenario_payload,
        calculated: calculated,
        expected: EXPECTED,
        matches_expected: calculated == EXPECTED
      )
    end

    private

    def bathing_addition
      @bathing_addition ||= Billing::Addition::Bathing.new
    end

    def training_addition
      @training_addition ||= Billing::Addition::IndividualFunctionalTraining.new
    end

    def scenario_payload
      {
        care_level: CARE_LEVEL,
        benefit_limit_units: BENEFIT_LIMIT_UNITS,
        monthly_use_count: MONTHLY_USE_COUNT,
        base_units: BASE_UNITS,
        addition_units: [
          {
            code: bathing_addition.code,
            name: bathing_addition.name,
            units: bathing_addition.units.value
          },
          {
            code: training_addition.code,
            name: training_addition.name,
            units: training_addition.units.value
          }
        ],
        improvement_rate: IMPROVEMENT_RATE
      }
    end
  end
end
