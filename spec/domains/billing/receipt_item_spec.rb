require "rails_helper"

RSpec.describe Billing::ReceiptItem do
  describe ".new" do
    it "builds immutable receipt item and calculates total_units" do
      item = described_class.new(
        service_code: "151111",
        name: "通所介護基本報酬",
        unit_score: Billing::CareServiceUnit.new(658),
        count: 22
      )

      expect(item.service_code).to eq("151111")
      expect(item.name).to eq("通所介護基本報酬")
      expect(item.unit_score).to eq(Billing::CareServiceUnit.new(658))
      expect(item.count).to eq(22)
      expect(item.total_units).to eq(Billing::CareServiceUnit.new(14_476))
      expect(item).to be_frozen
    end

    it "does not change when original input strings are mutated" do
      service_code = +"151111"
      name = +"通所介護基本報酬"

      item = described_class.new(
        service_code: service_code,
        name: name,
        unit_score: Billing::CareServiceUnit.new(658),
        count: 1
      )

      service_code << "9"
      name << "（改）"

      expect(item.service_code).to eq("151111")
      expect(item.name).to eq("通所介護基本報酬")
      expect(item.service_code).to be_frozen
      expect(item.name).to be_frozen
    end

    it "raises when service_code is invalid" do
      expect do
        described_class.new(
          service_code: "ABC",
          unit_score: Billing::CareServiceUnit.new(1),
          count: 1
        )
      end.to raise_error(ArgumentError, /service_code/)
    end

    it "raises when unit_score is invalid" do
      expect do
        described_class.new(service_code: "151111", unit_score: 658, count: 1)
      end.to raise_error(ArgumentError, /unit_score/)
    end

    it "raises when count is negative" do
      expect do
        described_class.new(
          service_code: "151111",
          unit_score: Billing::CareServiceUnit.new(1),
          count: -1
        )
      end.to raise_error(ArgumentError, /count/)
    end
  end
end
