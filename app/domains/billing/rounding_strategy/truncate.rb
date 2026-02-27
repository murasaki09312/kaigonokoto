require "bigdecimal"

module Billing
  module RoundingStrategy
    class Truncate
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
          raise ArgumentError, "truncate strategy only supports non-negative amounts"
        end

        decimal.floor
      end
    end
  end
end
