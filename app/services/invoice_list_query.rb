class InvoiceListQuery
  Result = Struct.new(
    :invoices,
    :line_counts,
    :meta,
    keyword_init: true
  )

  def initialize(tenant:, month_start:)
    @tenant = tenant
    @month_start = month_start
  end

  def call
    invoices = @tenant.invoices
      .for_month(@month_start)
      .includes(:client)
      .in_display_order

    line_counts = @tenant.invoice_lines
      .where(invoice_id: invoices.map(&:id))
      .group(:invoice_id)
      .count

    Result.new(
      invoices: invoices,
      line_counts: line_counts,
      meta: {
        month: @month_start.strftime("%Y-%m"),
        total: invoices.size,
        total_amount: invoices.sum(&:total_amount)
      }
    )
  end
end
