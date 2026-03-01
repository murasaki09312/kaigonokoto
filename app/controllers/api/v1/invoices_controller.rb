module Api
  module V1
    class InvoicesController < ApplicationController
      RECEIPT_SERVICE_CODE_BY_PRICE_ITEM_CODE = {
        "day_service_basic" => "151111"
      }.freeze
      DEFAULT_RECEIPT_SERVICE_CODE = "151111".freeze

      before_action :set_invoice, only: [ :show, :receipt ]

      def index
        authorize Invoice, :index?, policy_class: InvoicePolicy
        month_start = parse_month_param(params[:month], allow_blank: true)
        return if performed?

        result = InvoiceListQuery.new(tenant: current_tenant, month_start: month_start).call

        render json: {
          invoices: result.invoices.map { |invoice| invoice_response(invoice, line_count: result.line_counts.fetch(invoice.id, 0)) },
          meta: result.meta
        }, status: :ok
      end

      def show
        authorize @invoice, :show?, policy_class: InvoicePolicy

        invoice = current_tenant.invoices
          .includes(invoice_lines: [ :attendance, :price_item ])
          .find(@invoice.id)

        render json: {
          invoice: invoice_response(invoice, line_count: invoice.invoice_lines.size),
          invoice_lines: invoice.invoice_lines.order(:service_date, :id).map { |line| invoice_line_response(line) }
        }, status: :ok
      end

      def receipt
        authorize @invoice, :show?, policy_class: InvoicePolicy

        invoice = current_tenant.invoices
          .includes(invoice_lines: [ :price_item ])
          .find(@invoice.id)

        daily_records = invoice.invoice_lines.order(:service_date, :id).map do |line|
          Billing::DailyServiceRecord.new(
            base_units: Billing::CareServiceUnit.new(extract_units(line)),
            base_service_code: extract_service_code(line),
            base_name: line.item_name,
            additions: []
          )
        end

        receipt_items = Billing::MonthlyReceiptAggregator.new.aggregate(daily_records: daily_records)
        total_units = receipt_items.sum { |item| item.total_units.value }

        render json: {
          invoice: invoice_response(invoice, line_count: invoice.invoice_lines.size),
          receipt_items: receipt_items.map { |item| receipt_item_response(item) },
          meta: {
            total_units: total_units
          }
        }, status: :ok
      rescue ArgumentError => exception
        render_error("validation_error", exception.message, :unprocessable_entity)
      end

      def generate
        authorize Invoice, :generate?, policy_class: InvoicePolicy
        month_start = parse_month_param(params.fetch(:month), allow_blank: false)
        return if performed?

        result = InvoiceGenerationService.new(
          tenant: current_tenant,
          month_start: month_start,
          actor_user: current_user,
          mode: params[:mode].presence || "replace"
        ).call

        render json: {
          invoices: result.invoices.map { |invoice| invoice_response(invoice, line_count: invoice.invoice_lines.size) },
          meta: {
            month: month_start.strftime("%Y-%m"),
            generated: result.generated_count,
            replaced: result.replaced_count,
            skipped_existing: result.skipped_existing_count,
            skipped_fixed: result.skipped_fixed_count
          }
        }, status: :created
      rescue ActiveRecord::RecordInvalid => exception
        render_validation_error(exception.record)
      rescue ActiveRecord::RecordNotFound => exception
        render_error("validation_error", exception.message, :unprocessable_entity)
      rescue ArgumentError
        render_error("validation_error", "mode is invalid", :unprocessable_entity)
      end

      private

      def set_invoice
        @invoice = current_tenant.invoices.find(params[:id])
      end

      def parse_month_param(raw_month, allow_blank:)
        if raw_month.blank?
          return Date.current.beginning_of_month if allow_blank

          render_error("bad_request", "month is required", :bad_request)
          return nil
        end

        Date.strptime(raw_month.to_s, "%Y-%m").beginning_of_month
      rescue ArgumentError
        render_error("bad_request", "month must be YYYY-MM", :bad_request)
        nil
      end

      def extract_units(line)
        units = line.metadata&.fetch("units", nil)
        unit_value = Integer(units, exception: false)
        return unit_value if unit_value&.positive?

        line.line_total
      end

      def extract_service_code(line)
        metadata_code = line.metadata&.fetch("service_code", nil).to_s
        return metadata_code if metadata_code.match?(/\A\d{6}\z/)

        RECEIPT_SERVICE_CODE_BY_PRICE_ITEM_CODE.fetch(line.price_item&.code, DEFAULT_RECEIPT_SERVICE_CODE)
      end

      def receipt_item_response(item)
        {
          service_code: item.service_code,
          name: item.name,
          unit_score: item.unit_score.value,
          count: item.count,
          total_units: item.total_units.value
        }
      end
    end
  end
end
