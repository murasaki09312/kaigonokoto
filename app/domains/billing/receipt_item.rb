module Billing
  class ReceiptItem
    attr_reader :service_code, :name, :unit_score, :count, :total_units

    def initialize(service_code:, unit_score:, count:, name: nil)
      @service_code = coerce_service_code(service_code)
      @name = coerce_name(name)
      @unit_score = coerce_unit_score(unit_score)
      @count = coerce_count(count)
      @total_units = Billing::CareServiceUnit.new(@unit_score.value * @count)
      freeze
    end

    def ==(other)
      other.is_a?(self.class) &&
        service_code == other.service_code &&
        name == other.name &&
        unit_score == other.unit_score &&
        count == other.count &&
        total_units == other.total_units
    end

    alias eql? ==

    def hash
      [ self.class, service_code, name, unit_score, count, total_units ].hash
    end

    private

    def coerce_service_code(value)
      normalized = value.to_s
      return normalized.dup.freeze if normalized.match?(/\A\d{6}\z/)

      raise ArgumentError, "service_code must be 6 digits"
    end

    def coerce_name(value)
      return nil if value.nil?

      value.to_s.dup.freeze
    end

    def coerce_unit_score(value)
      return value if value.is_a?(Billing::CareServiceUnit)

      raise ArgumentError, "unit_score must be Billing::CareServiceUnit"
    end

    def coerce_count(value)
      integer_value = Integer(value, exception: false)
      if integer_value.nil? || integer_value.negative?
        raise ArgumentError, "count must be a non-negative Integer"
      end

      integer_value
    end
  end
end
