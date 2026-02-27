require "rails_helper"

RSpec.describe Billing::ImprovementAdditionCalculator do
  describe "#calculate_units" do
    it "calculates addition units from insured units with half-up rounding" do
      calculator = described_class.new
      insured_units = Billing::CareServiceUnit.new(16_765)

      result = calculator.calculate_units(insured_units: insured_units, rate: "0.245")

      expect(result).to eq(Billing::CareServiceUnit.new(4_107))
    end

    it "does not use total units beyond limit for improvement addition" do
      calculator = described_class.new
      total_units = Billing::CareServiceUnit.new(17_000)
      insured_units = Billing::CareServiceUnit.new(16_765)

      total_based = calculator.calculate_units(insured_units: total_units, rate: "0.245")
      insured_based = calculator.calculate_units(insured_units: insured_units, rate: "0.245")

      expect(total_based).to eq(Billing::CareServiceUnit.new(4_165))
      expect(insured_based).to eq(Billing::CareServiceUnit.new(4_107))
      expect(insured_based.value).to be < total_based.value
    end
  end
end
