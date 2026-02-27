require "rails_helper"

RSpec.describe Billing::CareServiceUnit do
  describe ".new" do
    it "raises error with negative value" do
      expect { described_class.new(-1) }.to raise_error(ArgumentError, /non-negative/)
    end

    it "creates immutable object" do
      unit = described_class.new(1532)

      expect(unit.value).to eq(1532)
      expect(unit).to be_frozen
    end
  end

  describe "#+" do
    it "returns new CareServiceUnit with summed value" do
      left = described_class.new(1200)
      right = described_class.new(332)

      result = left + right

      expect(result).to eq(described_class.new(1532))
      expect(left.value).to eq(1200)
      expect(right.value).to eq(332)
    end
  end

  describe "#-" do
    it "returns new CareServiceUnit with subtracted value" do
      left = described_class.new(1532)
      right = described_class.new(32)

      result = left - right

      expect(result).to eq(described_class.new(1500))
    end

    it "raises error when subtraction result becomes negative" do
      left = described_class.new(1)
      right = described_class.new(2)

      expect { left - right }.to raise_error(ArgumentError, /non-negative/)
    end
  end
end
