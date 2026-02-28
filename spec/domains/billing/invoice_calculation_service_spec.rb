require "rails_helper"

RSpec.describe Billing::InvoiceCalculationService do
  describe "#calculate" do
    it "calculates insurance and copayment amounts without excess units" do
      service = described_class.new

      result = service.calculate(
        insured_units: Billing::CareServiceUnit.new(15_000),
        self_pay_units: Billing::CareServiceUnit.new(0),
        regional_multiplier: Billing::RegionalMultiplier.new("10.90"),
        copayment_rate: "0.1"
      )

      expect(result.total_cost_yen).to eq(Billing::YenAmount.new(163_500))
      expect(result.insurance_claim_yen).to eq(Billing::YenAmount.new(147_150))
      expect(result.insured_copayment_yen).to eq(Billing::YenAmount.new(16_350))
      expect(result.excess_copayment_yen).to eq(Billing::YenAmount.new(0))
      expect(result.final_copayment_yen).to eq(Billing::YenAmount.new(16_350))
    end

    it "adds excess copayment and improvement units correctly" do
      service = described_class.new

      result = service.calculate(
        insured_units: Billing::CareServiceUnit.new(16_765),
        self_pay_units: Billing::CareServiceUnit.new(235),
        improvement_addition_units: Billing::CareServiceUnit.new(4_107),
        regional_multiplier: Billing::RegionalMultiplier.new("10.90"),
        copayment_rate: "0.1"
      )

      expect(result.total_cost_yen).to eq(Billing::YenAmount.new(227_504))
      expect(result.insurance_claim_yen).to eq(Billing::YenAmount.new(204_753))
      expect(result.insured_copayment_yen).to eq(Billing::YenAmount.new(22_751))
      expect(result.excess_copayment_yen).to eq(Billing::YenAmount.new(2_561))
      expect(result.final_copayment_yen).to eq(Billing::YenAmount.new(25_312))
    end

    it "defaults improvement addition units to zero" do
      service = described_class.new

      result = service.calculate(
        insured_units: Billing::CareServiceUnit.new(100),
        self_pay_units: Billing::CareServiceUnit.new(0),
        regional_multiplier: Billing::RegionalMultiplier.new("10.90"),
        copayment_rate: "0.1"
      )

      expect(result.total_cost_yen).to eq(Billing::YenAmount.new(1_090))
    end

    it "raises an error when copayment rate is unsupported" do
      service = described_class.new

      expect do
        service.calculate(
          insured_units: Billing::CareServiceUnit.new(15_000),
          self_pay_units: Billing::CareServiceUnit.new(0),
          regional_multiplier: Billing::RegionalMultiplier.new("10.90"),
          copayment_rate: "0.15"
        )
      end.to raise_error(ArgumentError, "copayment_rate must be one of 0.1, 0.2, 0.3")
    end

    it "raises an error when insured_units is invalid" do
      service = described_class.new

      expect do
        service.calculate(
          insured_units: 15_000,
          self_pay_units: Billing::CareServiceUnit.new(0),
          regional_multiplier: Billing::RegionalMultiplier.new("10.90"),
          copayment_rate: "0.1"
        )
      end.to raise_error(ArgumentError, "insured_units must be Billing::CareServiceUnit")
    end

    it "raises an error when regional_multiplier is invalid" do
      service = described_class.new

      expect do
        service.calculate(
          insured_units: Billing::CareServiceUnit.new(15_000),
          self_pay_units: Billing::CareServiceUnit.new(0),
          regional_multiplier: "10.90",
          copayment_rate: "0.1"
        )
      end.to raise_error(ArgumentError, "regional_multiplier must be Billing::RegionalMultiplier")
    end
  end
end
