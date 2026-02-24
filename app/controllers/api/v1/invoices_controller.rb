module Api
  module V1
    class InvoicesController < ApplicationController
      before_action :set_invoice, only: [ :show ]

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
    end
  end
end
