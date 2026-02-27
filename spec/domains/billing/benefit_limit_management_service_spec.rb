require "rails_helper"

RSpec.describe Billing::BenefitLimitManagementService do
  describe "#split_units" do
    it "splits insured and self-pay units when total exceeds benefit limit" do
      service = described_class.new

      result = service.split_units(
        monthly_total_units: Billing::CareServiceUnit.new(17_000),
        benefit_limit_units: Billing::CareServiceUnit.new(16_765)
      )

      expect(result.insured_units).to eq(Billing::CareServiceUnit.new(16_765))
      expect(result.self_pay_units).to eq(Billing::CareServiceUnit.new(235))
    end

    it "returns zero self-pay units when total is within benefit limit" do
      service = described_class.new

      result = service.split_units(
        monthly_total_units: Billing::CareServiceUnit.new(16_000),
        benefit_limit_units: Billing::CareServiceUnit.new(16_765)
      )

      expect(result.insured_units).to eq(Billing::CareServiceUnit.new(16_000))
      expect(result.self_pay_units).to eq(Billing::CareServiceUnit.new(0))
    end
  end
end
