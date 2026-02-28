class ApplicationController < ActionController::API
  include Pundit::Authorization

  ALLOWED_COPAYMENT_RATE_STRINGS = %w[0.1 0.2 0.3].freeze

  before_action :authenticate_request

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from ActiveRecord::ConnectionNotEstablished, with: :render_database_unavailable
  rescue_from PG::ConnectionBad, with: :render_database_unavailable if defined?(PG::ConnectionBad)

  private

  def authenticate_request
    Current.reset

    payload = JsonWebToken.decode(bearer_token)
    tenant = Tenant.find(payload.fetch(:tenant_id))
    user = tenant.users.find(payload.fetch(:user_id))

    Current.tenant = tenant
    Current.user = user
  rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound, KeyError, TypeError
    Current.reset
    render_error("unauthorized", "Unauthorized", :unauthorized)
  end

  def bearer_token
    authorization = request.headers["Authorization"].to_s
    return if authorization.blank?

    scheme, token = authorization.split(" ", 2)
    return if scheme != "Bearer" || token.blank?

    token
  end

  def pundit_user
    Current.user
  end

  def current_user
    Current.user
  end

  def current_tenant
    Current.tenant
  end

  def user_response(user)
    {
      id: user.id,
      tenant_id: user.tenant_id,
      name: user.name,
      email: user.email,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  def tenant_response(tenant)
    {
      id: tenant.id,
      name: tenant.name,
      slug: tenant.slug,
      city_name: tenant.city_name,
      facility_scale: tenant.facility_scale,
      created_at: tenant.created_at,
      updated_at: tenant.updated_at
    }
  end

  def client_response(client)
    line_summary = client_line_summary(client)

    {
      id: client.id,
      tenant_id: client.tenant_id,
      name: client.name,
      kana: client.kana,
      birth_date: client.birth_date,
      gender: client.gender,
      phone: client.phone,
      address: client.address,
      emergency_contact_name: client.emergency_contact_name,
      emergency_contact_phone: client.emergency_contact_phone,
      notes: client.notes,
      status: client.status,
      copayment_rate: client.copayment_rate,
      line_notification_available: line_summary.fetch(:line_notification_available),
      line_linked_family_count: line_summary.fetch(:line_linked_family_count),
      line_enabled_family_count: line_summary.fetch(:line_enabled_family_count),
      created_at: client.created_at,
      updated_at: client.updated_at
    }
  end

  def contract_response(contract)
    {
      id: contract.id,
      tenant_id: contract.tenant_id,
      client_id: contract.client_id,
      start_on: contract.start_on,
      end_on: contract.end_on,
      weekdays: contract.weekdays,
      services: contract.services,
      service_note: contract.service_note,
      shuttle_required: contract.shuttle_required,
      shuttle_note: contract.shuttle_note,
      created_at: contract.created_at,
      updated_at: contract.updated_at
    }
  end

  def reservation_response(reservation)
    {
      id: reservation.id,
      tenant_id: reservation.tenant_id,
      client_id: reservation.client_id,
      client_name: reservation.client&.name,
      service_date: reservation.service_date,
      start_time: reservation.start_time&.strftime("%H:%M"),
      end_time: reservation.end_time&.strftime("%H:%M"),
      status: reservation.status,
      notes: reservation.notes,
      created_at: reservation.created_at,
      updated_at: reservation.updated_at
    }
  end

  def attendance_response(attendance)
    {
      id: attendance.id,
      tenant_id: attendance.tenant_id,
      reservation_id: attendance.reservation_id,
      status: attendance.status,
      absence_reason: attendance.absence_reason,
      contacted_at: attendance.contacted_at,
      note: attendance.note,
      created_at: attendance.created_at,
      updated_at: attendance.updated_at
    }
  end

  def care_record_response(care_record)
    {
      id: care_record.id,
      tenant_id: care_record.tenant_id,
      reservation_id: care_record.reservation_id,
      recorded_by_user_id: care_record.recorded_by_user_id,
      body_temperature: care_record.body_temperature,
      systolic_bp: care_record.systolic_bp,
      diastolic_bp: care_record.diastolic_bp,
      pulse: care_record.pulse,
      spo2: care_record.spo2,
      care_note: care_record.care_note,
      handoff_note: care_record.handoff_note,
      created_at: care_record.created_at,
      updated_at: care_record.updated_at
    }
  end

  def line_notification_response(notification_summary)
    return nil if notification_summary.blank?

    {
      status: notification_summary[:status],
      total_count: notification_summary[:total_count],
      sent_count: notification_summary[:sent_count],
      failed_count: notification_summary[:failed_count],
      last_error_code: notification_summary[:last_error_code],
      last_error_message: notification_summary[:last_error_message],
      updated_at: notification_summary[:updated_at]
    }
  end

  def shuttle_leg_response(shuttle_leg, default_direction: nil)
    return default_shuttle_leg_response(default_direction) if shuttle_leg.blank?

    {
      id: shuttle_leg.id,
      tenant_id: shuttle_leg.tenant_id,
      shuttle_operation_id: shuttle_leg.shuttle_operation_id,
      direction: shuttle_leg.direction,
      status: shuttle_leg.status,
      planned_at: shuttle_leg.planned_at,
      actual_at: shuttle_leg.actual_at,
      handled_by_user_id: shuttle_leg.handled_by_user_id,
      handled_by_user_name: shuttle_leg.handled_by_user&.name,
      note: shuttle_leg.note,
      created_at: shuttle_leg.created_at,
      updated_at: shuttle_leg.updated_at
    }
  end

  def invoice_response(invoice, line_count: nil)
    breakdown = invoice_breakdown_response(invoice)

    {
      id: invoice.id,
      tenant_id: invoice.tenant_id,
      client_id: invoice.client_id,
      client_name: invoice.client&.name,
      billing_month: invoice.billing_month&.strftime("%Y-%m"),
      status: invoice.status,
      subtotal_amount: invoice.subtotal_amount,
      total_amount: invoice.total_amount,
      copayment_rate: breakdown[:copayment_rate],
      insurance_claim_amount: breakdown[:insurance_claim_amount],
      insured_copayment_amount: breakdown[:insured_copayment_amount],
      excess_copayment_amount: breakdown[:excess_copayment_amount],
      copayment_amount: breakdown[:copayment_amount],
      line_count: line_count,
      generated_at: invoice.generated_at,
      generated_by_user_id: invoice.generated_by_user_id,
      created_at: invoice.created_at,
      updated_at: invoice.updated_at
    }
  end

  def invoice_breakdown_response(invoice)
    total_cost_yen = Billing::YenAmount.new(invoice.subtotal_amount)
    breakdown = Billing::CopaymentBreakdownService.new.calculate(
      total_cost_yen: total_cost_yen,
      excess_copayment_yen: Billing::YenAmount.new(0),
      copayment_rate: extract_invoice_copayment_rate(invoice)
    )

    {
      copayment_rate: breakdown.copayment_rate.to_f,
      insurance_claim_amount: breakdown.insurance_claim_yen.value,
      insured_copayment_amount: breakdown.insured_copayment_yen.value,
      excess_copayment_amount: breakdown.excess_copayment_yen.value,
      copayment_amount: breakdown.final_copayment_yen.value
    }
  end

  def extract_invoice_copayment_rate(invoice)
    return nil unless invoice.association(:invoice_lines).loaded?

    invoice.invoice_lines.each do |line|
      rate = line.metadata&.fetch("copayment_rate", nil)
      next if rate.blank?

      normalized_rate = rate.to_s
      return normalized_rate if ALLOWED_COPAYMENT_RATE_STRINGS.include?(normalized_rate)
    end

    copayment_rate_from_client(invoice.client)
  end

  def copayment_rate_from_client(client)
    return nil if client.blank?
    return nil unless [ 1, 2, 3 ].include?(client.copayment_rate)

    "0.#{client.copayment_rate}"
  end

  def invoice_line_response(invoice_line)
    units = invoice_line.metadata&.fetch("units", nil)
    units_value = units.is_a?(Numeric) ? units.to_i : invoice_line.line_total

    {
      id: invoice_line.id,
      tenant_id: invoice_line.tenant_id,
      invoice_id: invoice_line.invoice_id,
      attendance_id: invoice_line.attendance_id,
      price_item_id: invoice_line.price_item_id,
      service_date: invoice_line.service_date,
      item_name: invoice_line.item_name,
      units: units_value,
      metadata: invoice_line.metadata,
      created_at: invoice_line.created_at,
      updated_at: invoice_line.updated_at
    }
  end

  def render_validation_error(record)
    render_error("validation_error", record.errors.full_messages.to_sentence, :unprocessable_entity)
  end

  def render_forbidden
    render_error("forbidden", "Forbidden", :forbidden)
  end

  def render_not_found
    render_error("not_found", "Not Found", :not_found)
  end

  def render_bad_request(exception)
    render_error("bad_request", exception.message, :bad_request)
  end

  def render_database_unavailable(_exception)
    render_error("database_unavailable", "Database is unavailable", :service_unavailable)
  end

  def render_error(code, message, status)
    render json: { error: { code: code, message: message } }, status: status
  end

  def default_shuttle_leg_response(direction)
    {
      id: nil,
      tenant_id: nil,
      shuttle_operation_id: nil,
      direction: direction,
      status: "pending",
      planned_at: nil,
      actual_at: nil,
      handled_by_user_id: nil,
      handled_by_user_name: nil,
      note: nil,
      created_at: nil,
      updated_at: nil
    }
  end

  def client_line_summary(client)
    family_members = if client.association(:family_members).loaded?
      client.family_members.to_a
    else
      client.family_members.to_a
    end

    linked_family_count = family_members.count { |family_member| family_member.line_user_id.present? }
    enabled_family_count = family_members.count do |family_member|
      family_member.active? && family_member.line_enabled? && family_member.line_user_id.present?
    end

    {
      line_notification_available: enabled_family_count.positive?,
      line_linked_family_count: linked_family_count,
      line_enabled_family_count: enabled_family_count
    }
  end
end
