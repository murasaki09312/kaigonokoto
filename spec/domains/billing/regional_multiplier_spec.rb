require "rails_helper"

RSpec.describe Billing::RegionalMultiplier do
  describe ".new" do
    it "creates immutable object" do
      multiplier = described_class.new("10.90")

      expect(multiplier.rate).to eq(BigDecimal("10.90"))
      expect(multiplier).to be_frozen
    end

    it "rejects negative rate" do
      expect { described_class.new("-10.90") }.to raise_error(ArgumentError, /non-negative/)
    end
  end

  describe "#calculate_yen" do
    it "calculates yen with truncation for 1 yen below fractions" do
      multiplier = described_class.new("10.90")
      unit = Billing::CareServiceUnit.new(1532)

      amount = multiplier.calculate_yen(unit: unit)

      expect(amount).to eq(Billing::YenAmount.new(16_698))
      expect(amount.value).to eq(16_698)
    end

    it "supports custom rounding strategy" do
      strategy = Class.new do
        def apply(_amount)
          99_999
        end
      end.new
      multiplier = described_class.new("10.90", rounding_strategy: strategy)
      unit = Billing::CareServiceUnit.new(1)

      expect(multiplier.calculate_yen(unit: unit)).to eq(Billing::YenAmount.new(99_999))
    end
  end
end
