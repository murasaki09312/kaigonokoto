class InvoiceGenerationService
  DEFAULT_PRICE_ITEM_CODE = "day_service_basic".freeze

  Result = Struct.new(
    :invoices,
    :generated_count,
    :replaced_count,
    :skipped_existing_count,
    :skipped_fixed_count,
    keyword_init: true
  )

  def initialize(tenant:, month_start:, actor_user:, mode: "replace")
    @tenant = tenant
    @month_start = month_start
    @month_end = month_start.end_of_month
    @actor_user = actor_user
    @mode = mode.to_s
  end

  def call
    validate_mode!
    price_item = resolve_price_item!

    invoices = []
    generated_count = 0
    replaced_count = 0
    skipped_existing_count = 0
    skipped_fixed_count = 0

    with_generation_lock! do
      attendance_groups = grouped_attendances

      if @mode == "replace"
        _removed_count, skipped_fixed_removed_count = remove_obsolete_draft_invoices!(attendance_groups.keys)
        skipped_fixed_count += skipped_fixed_removed_count
      end

      attendance_groups.each do |client_id, attendances|
        invoice = @tenant.invoices.find_by(client_id: client_id, billing_month: @month_start)

        if invoice&.status_fixed?
          skipped_fixed_count += 1
          next
        end

        if invoice.present? && @mode == "skip"
          skipped_existing_count += 1
          next
        end

        replacing = invoice.present?
        invoice ||= @tenant.invoices.new(client_id: client_id, billing_month: @month_start)

        ActiveRecord::Base.transaction do
          invoice.assign_attributes(
            status: :draft,
            generated_at: Time.current,
            generated_by_user: @actor_user
          )
          invoice.save! if invoice.new_record? || invoice.changed?

          invoice.invoice_lines.destroy_all if replacing
          build_invoice_lines!(invoice: invoice, attendances: attendances, price_item: price_item)

          invoice.recalculate_totals!
          invoice.save!
        end

        invoices << invoice
        generated_count += 1
        replaced_count += 1 if replacing
      end
    end

    Result.new(
      invoices: invoices,
      generated_count: generated_count,
      replaced_count: replaced_count,
      skipped_existing_count: skipped_existing_count,
      skipped_fixed_count: skipped_fixed_count
    )
  end

  private

  def validate_mode!
    return if %w[replace skip].include?(@mode)

    raise ArgumentError, "mode is invalid"
  end

  def resolve_price_item!
    active_items = @tenant.price_items.active_for(@month_start)
    active_items.find_by(code: DEFAULT_PRICE_ITEM_CODE) || active_items.order(:id).first || missing_price_item!
  end

  def missing_price_item!
    raise ActiveRecord::RecordNotFound, "No active price item found for invoice generation"
  end

  def grouped_attendances
    @tenant.attendances
      .joins(:reservation)
      .where(status: Attendance.statuses.fetch("present"))
      .where(reservations: { service_date: @month_start..@month_end })
      .includes(:reservation)
      .order("reservations.client_id ASC, reservations.service_date ASC, attendances.id ASC")
      .group_by { |attendance| attendance.reservation.client_id }
  end

  def build_invoice_lines!(invoice:, attendances:, price_item:)
    attendances.each do |attendance|
      reservation = attendance.reservation

      invoice.invoice_lines.create!(
        tenant: @tenant,
        attendance: attendance,
        price_item: price_item,
        service_date: reservation.service_date,
        item_name: price_item.name,
        quantity: 1.0,
        unit_price: price_item.unit_price,
        line_total: price_item.unit_price,
        metadata: {
          reservation_id: reservation.id,
          attendance_status: attendance.status
        }
      )
    end
  end

  def remove_obsolete_draft_invoices!(target_client_ids)
    invoices = @tenant.invoices.for_month(@month_start)
    invoices = invoices.where.not(client_id: target_client_ids) if target_client_ids.present?

    removed_count = 0
    skipped_fixed_count = 0

    invoices.find_each do |invoice|
      if invoice.status_fixed?
        skipped_fixed_count += 1
        next
      end

      invoice.destroy!
      removed_count += 1
    end

    [ removed_count, skipped_fixed_count ]
  end

  def with_generation_lock!
    lock_key = @month_start.strftime("%Y%m").to_i

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(#{@tenant.id}, #{lock_key})")
      yield
    end
  end
end
