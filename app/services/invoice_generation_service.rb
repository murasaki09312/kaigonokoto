class InvoiceGenerationService
  DEFAULT_PRICE_ITEM_CODE = "day_service_basic".freeze
  DEFAULT_IMPROVEMENT_ADDITION_RATE = BigDecimal("0.245")
  BASIC_SERVICE_CODE = "151111".freeze

  ADDITION_DEFINITIONS = {
    bath: {
      contract_key: "bath",
      price_item_code: "day_service_bathing_1",
      service_code: "155011"
    },
    rehabilitation: {
      contract_key: "rehabilitation",
      price_item_code: "day_service_individual_training_1_ro",
      service_code: "155052"
    }
  }.freeze

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
    price_items = resolve_price_items!

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
            copayment_rate: copayment_rate_for_snapshot(invoice.client),
            generated_at: Time.current,
            generated_by_user: @actor_user
          )
          invoice.save! if invoice.new_record? || invoice.changed?

          invoice.invoice_lines.destroy_all if replacing
          build_invoice_lines!(invoice: invoice, attendances: attendances, price_items: price_items)

          apply_invoice_amounts!(invoice: invoice)
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

  def resolve_price_items!
    active_items = @tenant.price_items.active_for(@month_start)
    base_item = active_items.find_by(code: DEFAULT_PRICE_ITEM_CODE) || active_items.order(:id).first || missing_price_item!
    addition_items = active_items.where(code: addition_price_item_codes).index_by(&:code)

    {
      base: base_item,
      additions: addition_items
    }
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

  def build_invoice_lines!(invoice:, attendances:, price_items:)
    copayment_rate = copayment_rate_decimal_for(invoice.copayment_rate, record: invoice)
    base_price_item = price_items.fetch(:base)
    addition_price_items = price_items.fetch(:additions)

    attendances.each do |attendance|
      reservation = attendance.reservation
      base_units = units_for(price_item: base_price_item)

      invoice.invoice_lines.create!(
        tenant: @tenant,
        attendance: attendance,
        price_item: base_price_item,
        service_date: reservation.service_date,
        item_name: base_price_item.name,
        quantity: 1.0,
        unit_price: base_units,
        line_total: base_units,
        metadata: {
          reservation_id: reservation.id,
          attendance_status: attendance.status,
          service_code: BASIC_SERVICE_CODE,
          units: base_units,
          copayment_rate: copayment_rate.to_s("F")
        }
      )

      addition_price_items_for(reservation: reservation, addition_price_items: addition_price_items).each do |definition, addition_price_item|
        addition_units = units_for(price_item: addition_price_item)

        invoice.invoice_lines.create!(
          tenant: @tenant,
          attendance: nil,
          price_item: addition_price_item,
          service_date: reservation.service_date,
          item_name: addition_price_item.name,
          quantity: 1.0,
          unit_price: addition_units,
          line_total: addition_units,
          metadata: {
            reservation_id: reservation.id,
            source_attendance_id: attendance.id,
            attendance_status: attendance.status,
            service_code: definition.fetch(:service_code),
            units: addition_units,
            copayment_rate: copayment_rate.to_s("F")
          }
        )
      end
    end
  end

  def apply_invoice_amounts!(invoice:)
    monthly_total_units = Billing::CareServiceUnit.new(invoice.invoice_lines.sum(:line_total))
    split = split_units_for(client: invoice.client, monthly_total_units: monthly_total_units)
    improvement_units = improvement_units_for(invoice: invoice, insured_units: split.insured_units)

    result = Billing::InvoiceCalculationService.new.calculate(
      insured_units: split.insured_units,
      self_pay_units: split.self_pay_units,
      improvement_addition_units: improvement_units,
      regional_multiplier: regional_multiplier,
      copayment_rate: copayment_rate_decimal_for(invoice.copayment_rate, record: invoice)
    )

    invoice.subtotal_amount = result.total_cost_yen.value
    invoice.total_amount = result.final_copayment_yen.value
    invoice.insurance_claim_amount = result.insurance_claim_yen.value if invoice.respond_to?(:insurance_claim_amount=)
    invoice.insured_copayment_amount = result.insured_copayment_yen.value if invoice.respond_to?(:insured_copayment_amount=)
    invoice.excess_copayment_amount = result.excess_copayment_yen.value if invoice.respond_to?(:excess_copayment_amount=)
  end

  def units_for(price_item:)
    units = Integer(price_item.unit_price, exception: false)
    return units if units&.positive?

    raise ActiveRecord::RecordInvalid, price_item
  end

  def copayment_rate_for_snapshot(client)
    rate = Integer(client.copayment_rate, exception: false)
    return rate if [ 1, 2, 3 ].include?(rate)

    raise ActiveRecord::RecordInvalid, client
  end

  def copayment_rate_decimal_for(rate, record:)
    case rate
    when 1 then BigDecimal("0.1")
    when 2 then BigDecimal("0.2")
    when 3 then BigDecimal("0.3")
    else
      raise ActiveRecord::RecordInvalid, record
    end
  end

  def regional_multiplier
    @regional_multiplier ||= begin
      city_name = @tenant.city_name.presence || "目黒区"
      area_grade = Billing::AreaGradeResolver.new.resolve(city_name: city_name)
      area_grade.to_regional_multiplier
    rescue ArgumentError => exception
      raise ActiveRecord::RecordNotFound, "Regional multiplier is unavailable: #{exception.message}"
    end
  end

  def split_units_for(client:, monthly_total_units:)
    benefit_limit_units = benefit_limit_units_for(client: client)
    if benefit_limit_units.nil?
      return Billing::BenefitLimitManagementService::Result.new(
        insured_units: monthly_total_units,
        self_pay_units: Billing::CareServiceUnit.new(0)
      )
    end

    Billing::BenefitLimitManagementService.new.split_units(
      monthly_total_units: monthly_total_units,
      benefit_limit_units: benefit_limit_units
    )
  end

  def benefit_limit_units_for(client:)
    column_value = Integer(client.benefit_limit_units, exception: false)
    return Billing::CareServiceUnit.new(column_value) unless column_value.nil?

    notes = client.notes.to_s
    match = notes.match(/限度額\s*([0-9,]+)\s*単位/u)
    if match
      parsed = match[1].delete(",").to_i
      if parsed.positive?
        Rails.logger.warn("[InvoiceGenerationService] using deprecated notes-based benefit limit for client_id=#{client.id}")
        return Billing::CareServiceUnit.new(parsed)
      end
    end

    if notes.present?
      Rails.logger.warn("[InvoiceGenerationService] could not resolve benefit_limit_units for client_id=#{client.id}")
    end
    nil
  end

  def improvement_units_for(invoice:, insured_units:)
    return Billing::CareServiceUnit.new(0) unless invoice_has_additions?(invoice)

    Billing::ImprovementAdditionCalculator.new.calculate_units(
      insured_units: insured_units,
      rate: DEFAULT_IMPROVEMENT_ADDITION_RATE
    )
  end

  def invoice_has_additions?(invoice)
    invoice.invoice_lines.any? do |line|
      service_code = line.metadata&.fetch("service_code", nil).to_s
      ADDITION_DEFINITIONS.values.any? { |definition| definition.fetch(:service_code) == service_code }
    end
  end

  def addition_price_item_codes
    ADDITION_DEFINITIONS.values.map { |definition| definition.fetch(:price_item_code) }
  end

  def addition_price_items_for(reservation:, addition_price_items:)
    services = active_contract_services_for(client_id: reservation.client_id, service_date: reservation.service_date)
    return [] if services.blank?

    ADDITION_DEFINITIONS.each_value.each_with_object([]) do |definition, entries|
      contract_key = definition.fetch(:contract_key)
      next unless truthy_contract_service?(services[contract_key] || services[contract_key.to_sym])

      addition_price_item = addition_price_items[definition.fetch(:price_item_code)]
      next if addition_price_item.nil?

      entries << [ definition, addition_price_item ]
    end
  end

  def active_contract_services_for(client_id:, service_date:)
    contract = @tenant.contracts
      .where(client_id: client_id)
      .where("start_on <= ?", service_date)
      .where("end_on IS NULL OR end_on >= ?", service_date)
      .order(start_on: :desc)
      .first

    contract&.services
  end

  def truthy_contract_service?(value)
    value == true || value.to_s.casecmp("true").zero? || value.to_s == "1"
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
