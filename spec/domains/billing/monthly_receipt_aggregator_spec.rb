require "rails_helper"

RSpec.describe Billing::MonthlyReceiptAggregator do
  describe "#aggregate" do
    it "aggregates service entries by service_code across daily records" do
      daily_records = Array.new(22) do |index|
        Billing::DailyServiceRecord.new(
          base_units: Billing::CareServiceUnit.new(658),
          base_service_code: "151111",
          additions: index < 10 ? [ Billing::Addition::Bathing.new ] : []
        )
      end

      result = described_class.new.aggregate(daily_records: daily_records)
      by_code = result.index_by(&:service_code)

      expect(by_code.keys).to include("151111", "155011")

      basic_item = by_code.fetch("151111")
      expect(basic_item.name).to eq("通所介護基本報酬")
      expect(basic_item.unit_score).to eq(Billing::CareServiceUnit.new(658))
      expect(basic_item.count).to eq(22)
      expect(basic_item.total_units).to eq(Billing::CareServiceUnit.new(14_476))

      bathing_item = by_code.fetch("155011")
      expect(bathing_item.name).to eq("入浴介助加算I")
      expect(bathing_item.unit_score).to eq(Billing::CareServiceUnit.new(40))
      expect(bathing_item.count).to eq(10)
      expect(bathing_item.total_units).to eq(Billing::CareServiceUnit.new(400))
    end

    it "returns empty array for empty records" do
      result = described_class.new.aggregate(daily_records: [])
      expect(result).to eq([])
    end

    it "raises for invalid daily_records type" do
      expect do
        described_class.new.aggregate(daily_records: "invalid")
      end.to raise_error(ArgumentError, /daily_records must be an Array/)
    end

    it "raises when daily_records include invalid element" do
      expect do
        described_class.new.aggregate(daily_records: [ Object.new ])
      end.to raise_error(ArgumentError, /Billing::DailyServiceRecord/)
    end
  end
end
