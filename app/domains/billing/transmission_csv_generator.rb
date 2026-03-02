require "csv"

module Billing
  class TransmissionCsvGenerator
    def initialize(invoice:, receipt_items:)
      @invoice = invoice
      @receipt_items = coerce_receipt_items(receipt_items)
    end

    def generate
      CSV.generate(force_quotes: false) do |csv|
        csv << base_record
        @receipt_items.each { |item| csv << detail_record(item) }
        csv << summary_record
      end
    end

    private

    def coerce_receipt_items(items)
      unless items.is_a?(Array) && items.all? { |item| item.is_a?(Billing::ReceiptItem) }
        raise ArgumentError, "receipt_items must be an Array of Billing::ReceiptItem"
      end

      items
    end

    def base_record
      [
        "1",
        billing_month_code,
        business_office_number,
        @invoice.client_id.to_s,
        @invoice.copayment_rate.to_s
      ]
    end

    def detail_record(item)
      [
        "2",
        item.service_code,
        item.count.to_s,
        item.unit_score.value.to_s,
        item.total_units.value.to_s
      ]
    end

    def summary_record
      [
        "3",
        total_units.to_s,
        @invoice.insurance_claim_amount.to_s,
        @invoice.total_amount.to_s
      ]
    end

    def billing_month_code
      month = @invoice.billing_month
      return month.strftime("%Y%m") if month.respond_to?(:strftime)

      month.to_s.delete("-")
    end

    def business_office_number
      candidate = @invoice.tenant&.slug.to_s.gsub(/\D/, "")
      candidate = @invoice.tenant_id.to_s if candidate.blank?
      candidate.rjust(10, "0").last(10)
    end

    def total_units
      @receipt_items.sum { |item| item.total_units.value }
    end
  end
end
