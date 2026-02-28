class InvoiceMonthlyIntegrationCaseGenerationService
  CASE_CLIENT_NAME = "結合テスト利用者（限界突破）".freeze
  CASE_ITEM_NAME = "通所介護（7時間以上8時間未満+入浴介助加算+個別機能訓練加算）".freeze

  Result = Struct.new(:invoice, :flow, keyword_init: true)

  def initialize(tenant:, month_start:, actor_user:)
    @tenant = tenant
    @month_start = month_start
    @actor_user = actor_user
  end

  def call
    flow = Billing::MonthlyIntegrationCase.new.call

    ActiveRecord::Base.transaction do
      client = find_or_create_client!
      invoice = @tenant.invoices.find_or_initialize_by(client: client, billing_month: @month_start)
      raise_if_fixed!(invoice)

      invoice.assign_attributes(
        status: :draft,
        generated_at: Time.current,
        generated_by_user: @actor_user
      )
      invoice.save! if invoice.new_record? || invoice.changed?

      invoice.invoice_lines.destroy_all
      build_case_lines!(invoice: invoice, flow: flow)
      invoice.recalculate_totals!
      invoice.save!

      Result.new(invoice: invoice, flow: flow)
    end
  end

  private

  def find_or_create_client!
    @tenant.clients.find_or_create_by!(name: CASE_CLIENT_NAME) do |client|
      client.status = :active
    end
  end

  def raise_if_fixed!(invoice)
    return unless invoice.persisted? && invoice.status_fixed?

    invoice.errors.add(:base, "対象月の請求が確定済みのため上書きできません")
    raise ActiveRecord::RecordInvalid, invoice
  end

  def build_case_lines!(invoice:, flow:)
    daily_units = flow.calculated.fetch(:daily_total_units)

    Billing::MonthlyIntegrationCase::MONTHLY_USE_COUNT.times do |index|
      invoice.invoice_lines.create!(
        tenant: @tenant,
        service_date: @month_start + index,
        item_name: CASE_ITEM_NAME,
        quantity: 1.0,
        unit_price: daily_units,
        line_total: daily_units,
        metadata: line_metadata(index: index, flow: flow)
      )
    end
  end

  def line_metadata(index:, flow:)
    return {} unless index.zero?

    {
      integration_case: true,
      monthly_use_count: Billing::MonthlyIntegrationCase::MONTHLY_USE_COUNT,
      flow: {
        calculated: flow.calculated,
        expected: flow.expected,
        matches_expected: flow.matches_expected
      }
    }
  end
end
