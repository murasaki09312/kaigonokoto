module Billing
  module Addition
    class IndividualFunctionalTraining
      UNITS = Billing::CareServiceUnit.new(76)

      def code
        :individual_functional_training
      end

      def name
        "個別機能訓練加算Iロ"
      end

      def units
        UNITS
      end
    end
  end
end
