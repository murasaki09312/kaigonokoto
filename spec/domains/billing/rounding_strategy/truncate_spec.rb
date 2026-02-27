require "rails_helper"

RSpec.describe Billing::RoundingStrategy::Truncate do
  describe "#apply" do
    it "floors decimal amount under 1 yen" do
      strategy = described_class.new
      amount = BigDecimal("16698.8")

      expect(strategy.apply(amount)).to eq(16_698)
    end

    it "rejects negative amount to avoid ambiguous floor behavior" do
      strategy = described_class.new

      expect { strategy.apply(BigDecimal("-1.2")) }
        .to raise_error(ArgumentError, /non-negative/)
    end
  end
end
