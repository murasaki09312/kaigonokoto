require "rails_helper"

RSpec.describe Billing::CopaymentBreakdownService do
  describe "#calculate" do
    it "splits insurance and copayment with default 10% rate" do
      service = described_class.new

      result = service.calculate(total_cost_yen: Billing::YenAmount.new(163_500))

      expect(result.copayment_rate).to eq(BigDecimal("0.1"))
      expect(result.insurance_claim_yen).to eq(Billing::YenAmount.new(147_150))
      expect(result.insured_copayment_yen).to eq(Billing::YenAmount.new(16_350))
      expect(result.excess_copayment_yen).to eq(Billing::YenAmount.new(0))
      expect(result.final_copayment_yen).to eq(Billing::YenAmount.new(16_350))
    end

    it "adds excess copayment to final amount" do
      service = described_class.new

      result = service.calculate(
        total_cost_yen: Billing::YenAmount.new(227_504),
        excess_copayment_yen: Billing::YenAmount.new(2_561),
        copayment_rate: "0.1"
      )

      expect(result.insurance_claim_yen).to eq(Billing::YenAmount.new(204_753))
      expect(result.insured_copayment_yen).to eq(Billing::YenAmount.new(22_751))
      expect(result.final_copayment_yen).to eq(Billing::YenAmount.new(25_312))
    end

    it "supports 20% copayment" do
      service = described_class.new

      result = service.calculate(
        total_cost_yen: Billing::YenAmount.new(1_200),
        copayment_rate: "0.2"
      )

      expect(result.insurance_claim_yen).to eq(Billing::YenAmount.new(960))
      expect(result.insured_copayment_yen).to eq(Billing::YenAmount.new(240))
    end

    it "raises an error for invalid copayment rate" do
      service = described_class.new

      expect do
        service.calculate(
          total_cost_yen: Billing::YenAmount.new(1_200),
          copayment_rate: "0.15"
        )
      end.to raise_error(ArgumentError, "copayment_rate must be one of 0.1, 0.2, 0.3")
    end

    it "raises an error when total_cost_yen is invalid" do
      service = described_class.new

      expect do
        service.calculate(total_cost_yen: 1200)
      end.to raise_error(ArgumentError, "total_cost_yen must be Billing::YenAmount")
    end
  end
end
