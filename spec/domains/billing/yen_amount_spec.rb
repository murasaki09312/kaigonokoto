require "rails_helper"

RSpec.describe Billing::YenAmount do
  describe ".new" do
    it "raises error with negative value" do
      expect { described_class.new(-1) }.to raise_error(ArgumentError, /non-negative/)
    end

    it "creates immutable object" do
      amount = described_class.new(16_698)

      expect(amount.value).to eq(16_698)
      expect(amount).to be_frozen
    end
  end

  describe "#+" do
    it "returns new YenAmount with summed value" do
      left = described_class.new(10_000)
      right = described_class.new(6_698)

      result = left + right

      expect(result).to eq(described_class.new(16_698))
    end
  end

  describe "#-" do
    it "returns new YenAmount with subtracted value" do
      left = described_class.new(16_698)
      right = described_class.new(698)

      result = left - right

      expect(result).to eq(described_class.new(16_000))
    end

    it "raises error when subtraction result becomes negative" do
      left = described_class.new(100)
      right = described_class.new(101)

      expect { left - right }.to raise_error(ArgumentError, /non-negative/)
    end
  end
end
