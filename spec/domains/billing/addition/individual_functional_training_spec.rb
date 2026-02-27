require "rails_helper"

RSpec.describe Billing::Addition::IndividualFunctionalTraining do
  describe "#units" do
    it "returns 76 units for individual functional training addition I-ro" do
      addition = described_class.new

      expect(addition.units).to eq(Billing::CareServiceUnit.new(76))
    end
  end

  describe "#code" do
    it "returns stable code" do
      expect(described_class.new.code).to eq(:individual_functional_training)
    end
  end
end
