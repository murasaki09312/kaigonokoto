require "rails_helper"

RSpec.describe Billing::AreaGrade do
  describe ".new" do
    it "builds grade_1 with unit price" do
      grade = described_class.new(code: :grade_1)

      expect(grade.code).to eq(:grade_1)
      expect(grade.unit_price).to eq(BigDecimal("10.90"))
      expect(grade).to be_frozen
    end

    it "raises for unsupported code" do
      expect { described_class.new(code: :grade_9) }
        .to raise_error(ArgumentError, /unsupported area grade/)
    end
  end

  describe "#to_regional_multiplier" do
    it "builds Billing::RegionalMultiplier with grade unit price" do
      grade = described_class.new(code: :grade_1)
      unit = Billing::CareServiceUnit.new(1532)

      amount = grade.to_regional_multiplier.calculate_yen(unit: unit)

      expect(amount).to eq(Billing::YenAmount.new(16_698))
    end
  end
end
