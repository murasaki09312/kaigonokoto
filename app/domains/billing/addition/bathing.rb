module Billing
  module Addition
    class Bathing
      UNITS = Billing::CareServiceUnit.new(40)
      SERVICE_CODE = "155011".freeze

      def code
        :bathing
      end

      def name
        "入浴介助加算I"
      end

      def units
        UNITS
      end

      def service_code
        SERVICE_CODE
      end
    end
  end
end
