require "rails_helper"

RSpec.describe Billing::Addition::Bathing do
  describe "#units" do
    it "returns 40 units for bathing addition I" do
      addition = described_class.new

      expect(addition.units).to eq(Billing::CareServiceUnit.new(40))
    end
  end

  describe "#code" do
    it "returns stable code" do
      expect(described_class.new.code).to eq(:bathing)
    end
  end
end
