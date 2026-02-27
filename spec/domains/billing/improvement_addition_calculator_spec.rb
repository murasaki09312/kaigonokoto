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

    it "raises an error when insured_units is not CareServiceUnit" do
      calculator = described_class.new

      expect do
        calculator.calculate_units(insured_units: 16_765, rate: "0.245")
      end.to raise_error(ArgumentError, "insured_units must be Billing::CareServiceUnit")
    end

    it "raises an error when rate is negative" do
      calculator = described_class.new

      expect do
        calculator.calculate_units(
          insured_units: Billing::CareServiceUnit.new(16_765),
          rate: "-0.1"
        )
      end.to raise_error(ArgumentError, "rate must be between 0 and 1")
    end

    it "raises an error when rate is greater than 1" do
      calculator = described_class.new

      expect do
        calculator.calculate_units(
          insured_units: Billing::CareServiceUnit.new(16_765),
          rate: "1.1"
        )
      end.to raise_error(ArgumentError, "rate must be between 0 and 1")
    end

    it "raises an error when rate is not numeric" do
      calculator = described_class.new

      expect do
        calculator.calculate_units(
          insured_units: Billing::CareServiceUnit.new(16_765),
          rate: "not-a-number"
        )
      end.to raise_error(ArgumentError, "rate must be BigDecimal, Numeric, or String")
    end
  end
end
