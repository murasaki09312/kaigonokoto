module Billing
  class DailyServiceRecord
    attr_reader :base_units, :additions

    def initialize(base_units:, additions: [])
      @base_units = coerce_base_units(base_units)
      @additions = coerce_additions(additions)
      freeze
    end

    def total_units
      additions.reduce(base_units) do |sum, addition|
        sum + addition.units
      end
    end

    private

    def coerce_base_units(value)
      return value if value.is_a?(Billing::CareServiceUnit)

      raise ArgumentError, "base_units must be Billing::CareServiceUnit"
    end

    def coerce_additions(values)
      unless values.is_a?(Array)
        raise ArgumentError, "additions must be an Array"
      end

      values.map do |addition|
        unless addition.respond_to?(:units)
          raise ArgumentError, "addition must respond to #units"
        end

        units = addition.units
        unless units.is_a?(Billing::CareServiceUnit)
          raise ArgumentError, "addition#units must return Billing::CareServiceUnit"
        end

        addition
      end.freeze
    end
  end
end
