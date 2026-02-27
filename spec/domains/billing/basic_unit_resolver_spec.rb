require "rails_helper"

RSpec.describe Billing::BasicUnitResolver do
  describe "#resolve" do
    it "returns care units for normal scale x 7h_to_8h x care_level 1..5" do
      resolver = described_class.new

      expected = {
        1 => 658,
        2 => 777,
        3 => 861,
        4 => 980,
        5 => 1093
      }

      expected.each do |care_level, unit_value|
        result = resolver.resolve(
          care_level: care_level,
          duration_category: "7h_to_8h",
          facility_scale: "normal"
        )

        expect(result).to eq(Billing::CareServiceUnit.new(unit_value))
      end
    end

    it "accepts symbol duration category alias" do
      resolver = described_class.new

      result = resolver.resolve(
        care_level: 3,
        duration_category: :h7_to_h8,
        facility_scale: :normal
      )

      expect(result).to eq(Billing::CareServiceUnit.new(861))
    end

    it "raises for unsupported facility scale and duration combinations" do
      resolver = described_class.new

      expect do
        resolver.resolve(care_level: 1, duration_category: "7h_to_8h", facility_scale: "large_1")
      end.to raise_error(ArgumentError, /unsupported combination/)
    end

    it "raises for unsupported care level" do
      resolver = described_class.new

      expect do
        resolver.resolve(care_level: 6, duration_category: "7h_to_8h", facility_scale: "normal")
      end.to raise_error(ArgumentError, /care_level/)
    end
  end
end
