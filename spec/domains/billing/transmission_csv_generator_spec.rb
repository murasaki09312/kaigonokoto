require "rails_helper"
require "csv"

RSpec.describe Billing::TransmissionCsvGenerator do
  describe "#generate" do
    it "generates 3-layer transmission CSV rows" do
      tenant = Tenant.create!(name: "CSV Tenant", slug: "tenant-12345")
      client = tenant.clients.create!(name: "山田 太郎", status: :active, copayment_rate: 1)
      invoice = tenant.invoices.create!(
        client: client,
        billing_month: Date.new(2026, 2, 1),
        status: :draft,
        copayment_rate: 1,
        subtotal_amount: 163_500,
        total_amount: 16_350,
        insurance_claim_amount: 147_150,
        insured_copayment_amount: 16_350,
        excess_copayment_amount: 0
      )
      receipt_items = [
        Billing::ReceiptItem.new(
          service_code: "151111",
          name: "通所介護基本報酬",
          unit_score: Billing::CareServiceUnit.new(658),
          count: 22
        ),
        Billing::ReceiptItem.new(
          service_code: "155011",
          name: "入浴介助加算I",
          unit_score: Billing::CareServiceUnit.new(40),
          count: 10
        )
      ]

      csv = described_class.new(invoice: invoice, receipt_items: receipt_items).generate
      rows = CSV.parse(csv)

      expect(rows.size).to eq(4)
      expect(rows[0]).to eq([ "1", "202602", "0000012345", client.id.to_s, "1" ])
      expect(rows[1]).to eq([ "2", "151111", "22", "658", "14476" ])
      expect(rows[2]).to eq([ "2", "155011", "10", "40", "400" ])
      expect(rows[3]).to eq([ "3", "14876", "147150", "16350" ])
    end

    it "raises when receipt_items contain invalid object" do
      tenant = Tenant.create!(name: "CSV Tenant 2", slug: "tenant-csv-2")
      client = tenant.clients.create!(name: "佐藤 花子", status: :active, copayment_rate: 1)
      invoice = tenant.invoices.create!(
        client: client,
        billing_month: Date.new(2026, 2, 1),
        status: :draft,
        copayment_rate: 1,
        subtotal_amount: 0,
        total_amount: 0,
        insurance_claim_amount: 0,
        insured_copayment_amount: 0,
        excess_copayment_amount: 0
      )

      expect do
        described_class.new(invoice: invoice, receipt_items: [ "invalid" ]).generate
      end.to raise_error(ArgumentError, /receipt_items/)
    end
  end
end
