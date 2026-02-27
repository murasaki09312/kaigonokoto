require "bigdecimal"

module Billing
  module RoundingStrategy
    class HalfUp
      def apply(amount)
        decimal = case amount
        when BigDecimal
          amount
        when Numeric, String
          BigDecimal(amount.to_s)
        else
          raise ArgumentError, "amount must be BigDecimal, Numeric, or String"
        end

        if decimal.negative?
          raise ArgumentError, "half-up strategy only supports non-negative amounts"
        end

        decimal.round(0, half: :up).to_i
      end
    end
  end
end
