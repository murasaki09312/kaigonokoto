module Billing
  class MonthlyReceiptAggregator
    def aggregate(daily_records:)
      records = coerce_daily_records(daily_records)
      entries = records.flat_map(&:service_entries)

      grouped_entries = entries.group_by(&:service_code)
      grouped_entries.map do |service_code, group|
        unit_score = resolve_unit_score!(service_code, group)
        name = resolve_name!(service_code, group)

        Billing::ReceiptItem.new(
          service_code: service_code,
          name: name,
          unit_score: unit_score,
          count: group.size
        )
      end
    end

    private

    def coerce_daily_records(values)
      unless values.is_a?(Array)
        raise ArgumentError, "daily_records must be an Array"
      end

      values.map do |record|
        unless record.is_a?(Billing::DailyServiceRecord)
          raise ArgumentError, "daily_records must contain Billing::DailyServiceRecord"
        end

        record
      end
    end

    def resolve_unit_score!(service_code, group)
      unit_scores = group.map(&:units).uniq
      return unit_scores.first if unit_scores.one?

      raise ArgumentError, "unit score mismatch for service_code=#{service_code}"
    end

    def resolve_name!(service_code, group)
      names = group.map(&:name).compact.uniq
      return nil if names.empty?
      return names.first if names.one?

      raise ArgumentError, "service name mismatch for service_code=#{service_code}"
    end
  end
end
