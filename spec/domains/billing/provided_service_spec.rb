require "rails_helper"

RSpec.describe Billing::ProvidedService do
  describe ".new" do
    it "creates immutable service entry with service code and units" do
      service = described_class.new(
        service_code: "151111",
        units: Billing::CareServiceUnit.new(658),
        name: "通所介護基本報酬"
      )

      expect(service.service_code).to eq("151111")
      expect(service.units).to eq(Billing::CareServiceUnit.new(658))
      expect(service.name).to eq("通所介護基本報酬")
      expect(service).to be_frozen
    end

    it "raises for invalid service code format" do
      expect do
        described_class.new(service_code: "ABC", units: Billing::CareServiceUnit.new(1))
      end.to raise_error(ArgumentError, /service_code must be 6 digits/)
    end

    it "raises for invalid units type" do
      expect do
        described_class.new(service_code: "151111", units: 658)
      end.to raise_error(ArgumentError, /units must be Billing::CareServiceUnit/)
    end
  end
end
