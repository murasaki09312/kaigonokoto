require "rails_helper"

RSpec.describe Billing::DailyServiceRecord do
  describe "#total_units" do
    it "returns summed units of base units and additions" do
      record = described_class.new(
        base_units: Billing::CareServiceUnit.new(658),
        additions: [
          Billing::Addition::Bathing.new,
          Billing::Addition::IndividualFunctionalTraining.new
        ]
      )

      expect(record.total_units).to eq(Billing::CareServiceUnit.new(774))
    end

    it "returns base units when additions are empty" do
      record = described_class.new(base_units: Billing::CareServiceUnit.new(658), additions: [])

      expect(record.total_units).to eq(Billing::CareServiceUnit.new(658))
    end
  end

  describe ".new" do
    it "raises for invalid base_units type" do
      expect do
        described_class.new(base_units: 658, additions: [])
      end.to raise_error(ArgumentError, /base_units must be Billing::CareServiceUnit/)
    end

    it "raises for invalid addition interface" do
      expect do
        described_class.new(base_units: Billing::CareServiceUnit.new(658), additions: [ Object.new ])
      end.to raise_error(ArgumentError, /addition must respond to #units/)
    end
  end
end
