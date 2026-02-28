module Billing
  module Addition
    class IndividualFunctionalTraining
      UNITS = Billing::CareServiceUnit.new(76)
      SERVICE_CODE = "155052".freeze

      def code
        :individual_functional_training
      end

      def name
        "個別機能訓練加算Iロ"
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
