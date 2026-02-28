require "rails_helper"

RSpec.describe Billing::BasicUnitResolver do
  describe "#resolve" do
    it "returns provided services for normal scale x 7h_to_8h x care_level 1..5" do
      resolver = described_class.new

      expected = {
        1 => { units: 658, service_code: "151111" },
        2 => { units: 777, service_code: "151121" },
        3 => { units: 861, service_code: "151131" },
        4 => { units: 980, service_code: "151141" },
        5 => { units: 1093, service_code: "151151" }
      }

      expected.each do |care_level, entry|
        result = resolver.resolve(
          care_level: care_level,
          duration_category: "7h_to_8h",
          facility_scale: "normal"
        )

        expect(result.units).to eq(Billing::CareServiceUnit.new(entry.fetch(:units)))
        expect(result.service_code).to eq(entry.fetch(:service_code))
      end
    end

    it "accepts symbol duration category alias" do
      resolver = described_class.new

      result = resolver.resolve(
        care_level: 3,
        duration_category: :h7_to_h8,
        facility_scale: :normal
      )

      expect(result.units).to eq(Billing::CareServiceUnit.new(861))
      expect(result.service_code).to eq("151131")
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

    it "raises when duration_category is nil" do
      resolver = described_class.new

      expect do
        resolver.resolve(care_level: 1, duration_category: nil, facility_scale: "normal")
      end.to raise_error(ArgumentError, /duration_category/)
    end

    it "raises when duration_category is blank" do
      resolver = described_class.new

      expect do
        resolver.resolve(care_level: 1, duration_category: "", facility_scale: "normal")
      end.to raise_error(ArgumentError, /duration_category/)
    end
  end

  describe "#resolve_units" do
    it "returns only units for compatibility use-cases" do
      resolver = described_class.new

      result = resolver.resolve_units(
        care_level: 1,
        duration_category: "7h_to_8h",
        facility_scale: "normal"
      )

      expect(result).to eq(Billing::CareServiceUnit.new(658))
    end
  end
end
