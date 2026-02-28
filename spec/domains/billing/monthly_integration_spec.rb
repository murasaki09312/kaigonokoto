require "rails_helper"

RSpec.describe "Billing monthly integration" do
  it "connects daily record, monthly limit split, and improvement addition flow" do
    daily_record = Billing::DailyServiceRecord.new(
      base_units: Billing::CareServiceUnit.new(658),
      base_service_code: "151111",
      additions: [
        Billing::Addition::Bathing.new,
        Billing::Addition::IndividualFunctionalTraining.new
      ]
    )
    daily_total_units = daily_record.total_units

    expect(daily_total_units).to eq(Billing::CareServiceUnit.new(774))

    monthly_total_units = 22.times.reduce(Billing::CareServiceUnit.new(0)) do |sum, _|
      sum + daily_total_units
    end

    expect(monthly_total_units).to eq(Billing::CareServiceUnit.new(17_028))

    limit_service = Billing::BenefitLimitManagementService.new
    split_result = limit_service.split_units(
      monthly_total_units: monthly_total_units,
      benefit_limit_units: Billing::CareServiceUnit.new(16_765)
    )

    expect(split_result.insured_units).to eq(Billing::CareServiceUnit.new(16_765))
    expect(split_result.self_pay_units).to eq(Billing::CareServiceUnit.new(263))

    calculator = Billing::ImprovementAdditionCalculator.new
    improvement_units = calculator.calculate_units(
      insured_units: split_result.insured_units,
      rate: "0.245"
    )

    expect(improvement_units).to eq(Billing::CareServiceUnit.new(4_107))
  end
end
