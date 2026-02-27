module Billing
  module Addition
    class Bathing
      UNITS = Billing::CareServiceUnit.new(40)

      def code
        :bathing
      end

      def name
        "入浴介助加算I"
      end

      def units
        UNITS
      end
    end
  end
end
