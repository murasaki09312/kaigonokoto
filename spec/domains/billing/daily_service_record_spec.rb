require "rails_helper"

RSpec.describe Billing::DailyServiceRecord do
  describe "#total_units" do
    it "returns summed units of base units and additions" do
      record = described_class.new(
        base_units: Billing::CareServiceUnit.new(658),
        base_service_code: "151111",
        additions: [
          Billing::Addition::Bathing.new,
          Billing::Addition::IndividualFunctionalTraining.new
        ]
      )

      expect(record.total_units).to eq(Billing::CareServiceUnit.new(774))
    end

    it "returns base units when additions are empty" do
      record = described_class.new(
        base_units: Billing::CareServiceUnit.new(658),
        base_service_code: "151111",
        additions: []
      )

      expect(record.total_units).to eq(Billing::CareServiceUnit.new(658))
    end
  end

  describe "#service_entries" do
    it "returns basic and addition entries with service codes and units" do
      record = described_class.new(
        base_units: Billing::CareServiceUnit.new(658),
        base_service_code: "151111",
        additions: [
          Billing::Addition::Bathing.new,
          Billing::Addition::IndividualFunctionalTraining.new
        ]
      )

      entries = record.service_entries

      expect(entries.map(&:service_code)).to eq(%w[151111 155011 155052])
      expect(entries.map { |entry| entry.units.value }).to eq([ 658, 40, 76 ])
    end
  end

  describe ".new" do
    it "raises for invalid base_units type" do
      expect do
        described_class.new(base_units: 658, base_service_code: "151111", additions: [])
      end.to raise_error(ArgumentError, /base_units must be Billing::CareServiceUnit/)
    end

    it "raises for invalid addition interface" do
      expect do
        described_class.new(
          base_units: Billing::CareServiceUnit.new(658),
          base_service_code: "151111",
          additions: [ Object.new ]
        )
      end.to raise_error(ArgumentError, /addition must respond to #units/)
    end

    it "raises for invalid base_service_code" do
      expect do
        described_class.new(base_units: Billing::CareServiceUnit.new(658), base_service_code: "ABC123", additions: [])
      end.to raise_error(ArgumentError, /base_service_code must be 6 digits/)
    end
  end
end
