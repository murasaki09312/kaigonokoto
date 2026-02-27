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

        decimal.floor
      end
    end
  end
end
