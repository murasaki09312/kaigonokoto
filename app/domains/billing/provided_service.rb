module Billing
  class ProvidedService
    attr_reader :service_code, :units, :name

    def initialize(service_code:, units:, name: nil)
      @service_code = coerce_service_code(service_code)
      @units = coerce_units(units)
      @name = coerce_name(name)
      freeze
    end

    def ==(other)
      other.is_a?(self.class) &&
        service_code == other.service_code &&
        units == other.units &&
        name == other.name
    end

    alias eql? ==

    def hash
      [ self.class, service_code, units, name ].hash
    end

    private

    def coerce_service_code(value)
      normalized = value.to_s
      if normalized.match?(/\A\d{6}\z/)
        return normalized.dup.freeze
      end

      raise ArgumentError, "service_code must be 6 digits"
    end

    def coerce_units(value)
      return value if value.is_a?(Billing::CareServiceUnit)

      raise ArgumentError, "units must be Billing::CareServiceUnit"
    end

    def coerce_name(value)
      return nil if value.nil?

      value.to_s.dup.freeze
    end
  end
end
