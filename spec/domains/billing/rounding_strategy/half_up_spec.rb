require "rails_helper"

RSpec.describe Billing::RoundingStrategy::HalfUp do
  describe "#apply" do
    it "rounds half up for positive decimals" do
      strategy = described_class.new

      expect(strategy.apply(BigDecimal("4107.5"))).to eq(4108)
      expect(strategy.apply(BigDecimal("4107.49"))).to eq(4107)
    end

    it "rejects negative amounts" do
      strategy = described_class.new

      expect { strategy.apply(BigDecimal("-1.2")) }
        .to raise_error(ArgumentError, /non-negative/)
    end
  end
end
