module Billing
  class DailyServiceRecord
    DEFAULT_BASE_NAME = "通所介護基本報酬".freeze

    attr_reader :base_units, :base_service_code, :base_name, :additions

    def initialize(base_units:, additions: [], base_service_code:, base_name: DEFAULT_BASE_NAME)
      @base_units = coerce_base_units(base_units)
      @base_service_code = coerce_service_code(base_service_code, field_name: "base_service_code")
      @base_name = coerce_base_name(base_name)
      @additions = coerce_additions(additions)
      freeze
    end

    def total_units
      additions.reduce(base_units) do |sum, addition|
        sum + addition.units
      end
    end

    def service_entries
      basic_entry = Billing::ProvidedService.new(
        service_code: base_service_code,
        units: base_units,
        name: base_name
      )

      addition_entries = additions.map do |addition|
        Billing::ProvidedService.new(
          service_code: addition.service_code,
          units: addition.units,
          name: addition.name
        )
      end

      [ basic_entry, *addition_entries ].freeze
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
        unless addition.respond_to?(:service_code)
          raise ArgumentError, "addition must respond to #service_code"
        end

        units = addition.units
        unless units.is_a?(Billing::CareServiceUnit)
          raise ArgumentError, "addition#units must return Billing::CareServiceUnit"
        end
        coerce_service_code(addition.service_code, field_name: "addition#service_code")

        addition
      end.freeze
    end

    def coerce_service_code(value, field_name:)
      normalized = value.to_s
      return normalized if normalized.match?(/\A\d{6}\z/)

      raise ArgumentError, "#{field_name} must be 6 digits"
    end

    def coerce_base_name(value)
      normalized = value.to_s.strip
      raise ArgumentError, "base_name is required" if normalized.blank?

      normalized
    end
  end
end
