class ReservationsController < ApplicationController
  before_action :set_reservation, only: [ :show, :update, :destroy ]

  def index
    authorize Reservation, :index?, policy_class: ReservationPolicy
    from, to = parse_range_params
    return if performed?

    reservations = policy_scope(Reservation, policy_scope_class: ReservationPolicy::Scope)
      .within_dates(from, to)
      .includes(:client)
      .in_display_order

    render json: {
      reservations: reservations.map { |reservation| reservation_response(reservation) },
      meta: {
        total: reservations.size,
        from: from,
        to: to,
        capacity_by_date: capacity_by_date(from, to)
      }
    }, status: :ok
  end

  def show
    authorize @reservation, :show?, policy_class: ReservationPolicy

    render json: { reservation: reservation_response(@reservation) }, status: :ok
  end

  def create
    authorize Reservation, :create?, policy_class: ReservationPolicy
    client_id = reservation_params.fetch(:client_id)
    attrs = reservation_params.to_h.symbolize_keys
    client = current_tenant.clients.find(client_id)
    force_requested = ActiveModel::Type::Boolean.new.cast(attrs.delete(:force))
    status = resolve_status(attrs.delete(:status), default: "scheduled")
    return if performed?

    reservation = current_tenant.reservations.new(
      attrs.merge(client: client, status: status)
    )

    if scheduled_status?(status) && !force_override_allowed?(force_requested)
      save_with_capacity_guard!(reservation)
      return if performed?
    else
      return render_validation_error(reservation) unless reservation.save
    end

    render json: { reservation: reservation_response(reservation) }, status: :created
  rescue ActiveRecord::RecordInvalid => exception
    render_validation_error(exception.record)
  rescue ArgumentError => exception
    render_invalid_status_error(exception)
  end

  def update
    authorize @reservation, :update?, policy_class: ReservationPolicy
    attrs = reservation_params.to_h.symbolize_keys
    force_requested = ActiveModel::Type::Boolean.new.cast(attrs.delete(:force))
    attrs[:client] = current_tenant.clients.find(attrs.delete(:client_id)) if attrs.key?(:client_id)
    if attrs.key?(:status)
      attrs[:status] = resolve_status(attrs[:status], default: nil)
      return if performed?
    end

    @reservation.assign_attributes(attrs)
    next_status = @reservation.status

    if scheduled_status?(next_status) && !force_override_allowed?(force_requested)
      save_with_capacity_guard!(@reservation, exclude_id: @reservation.id)
      return if performed?
    else
      return render_validation_error(@reservation) unless @reservation.save
    end

    render json: { reservation: reservation_response(@reservation) }, status: :ok
  rescue ArgumentError => exception
    render_invalid_status_error(exception)
  end

  def destroy
    authorize @reservation, :destroy?, policy_class: ReservationPolicy
    @reservation.destroy!

    head :no_content
  end

  def generate
    authorize Reservation, :generate?, policy_class: ReservationPolicy
    start_on = parse_iso_date(generate_params.fetch(:start_on), "start_on")
    end_on = parse_iso_date(generate_params.fetch(:end_on), "end_on")
    return if performed?

    if end_on < start_on
      return render_error("validation_error", "end_on must be on or after start_on", :unprocessable_entity)
    end

    force_requested = ActiveModel::Type::Boolean.new.cast(generate_params[:force])
    target_status = resolve_status(generate_params[:status], default: "scheduled")
    return if performed?

    result = ReservationGeneratorService.new(
      tenant: current_tenant,
      start_on: start_on,
      end_on: end_on,
      start_time: generate_params[:start_time],
      end_time: generate_params[:end_time],
      notes: generate_params[:notes],
      status: target_status,
      force: force_override_allowed?(force_requested)
    ).call

    render json: {
      reservations: result.reservations.map { |reservation| reservation_response(reservation) },
      meta: {
        total: result.reservations.size,
        capacity_skipped_dates: result.capacity_skipped_dates,
        existing_skipped_total: result.existing_skipped_total
      }
    }, status: :created
  rescue ActiveRecord::RecordInvalid => exception
    render_validation_error(exception.record)
  rescue ArgumentError => exception
    render_invalid_status_error(exception)
  end

  private

  def set_reservation
    @reservation = current_tenant.reservations.find(params[:id])
  end

  def reservation_params
    params.permit(
      :client_id,
      :service_date,
      :start_time,
      :end_time,
      :status,
      :notes,
      :force
    )
  end

  def generate_params
    params.permit(
      :start_on,
      :end_on,
      :start_time,
      :end_time,
      :status,
      :notes,
      :force
    )
  end

  def parse_range_params
    from = params[:from].present? ? parse_iso_date(params[:from], "from") : Date.current
    to = params[:to].present? ? parse_iso_date(params[:to], "to") : from
    return [ from, to ] if performed?
    return [ from, to ] if to >= from

    render_error("bad_request", "to must be on or after from", :bad_request)
    [ nil, nil ]
  end

  def parse_iso_date(value, field_name)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    render_error("bad_request", "#{field_name} must be ISO date (YYYY-MM-DD)", :bad_request)
    nil
  end

  def scheduled_status?(status)
    status.to_s == "scheduled"
  end

  def force_override_allowed?(force_requested)
    return false unless force_requested

    ReservationPolicy.new(current_user, Reservation).override_capacity?
  end

  def with_capacity_lock!(dates)
    Array(dates).uniq.sort.each do |date|
      lock_key = date.strftime("%Y%m%d").to_i
      ActiveRecord::Base.connection.execute(
        "SELECT pg_advisory_xact_lock(#{current_tenant.id}, #{lock_key})"
      )
    end

    yield
  end

  def save_with_capacity_guard!(reservation, exclude_id: nil)
    unless reservation.valid?
      render_validation_error(reservation)
      return
    end

    ActiveRecord::Base.transaction do
      with_capacity_lock!([ reservation.service_date ]) do
        if capacity_exceeded_on?(reservation.service_date, exclude_id: exclude_id)
          render_capacity_exceeded([ reservation.service_date ])
          raise ActiveRecord::Rollback
        end

        unless reservation.save
          render_validation_error(reservation)
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  def capacity_exceeded_on?(date, exclude_id: nil)
    relation = current_tenant.reservations.scheduled_on(date)
    relation = relation.where.not(id: exclude_id) if exclude_id.present?

    relation.count >= current_tenant.capacity_per_day
  end

  def capacity_by_date(from, to)
    capacity = current_tenant.capacity_per_day
    scheduled_counts = current_tenant.reservations
      .where(status: Reservation.statuses.fetch("scheduled"), service_date: from..to)
      .group(:service_date)
      .count

    (from..to).index_with do |date|
      scheduled = scheduled_counts.fetch(date, 0)
      {
        scheduled: scheduled,
        capacity: capacity,
        remaining: capacity - scheduled,
        exceeded: scheduled > capacity
      }
    end
  end

  def render_capacity_exceeded(conflicts)
    render json: {
      error: {
        code: "capacity_exceeded",
        message: "Capacity exceeded for one or more dates"
      },
      conflicts: conflicts
    }, status: :unprocessable_entity
  end

  def resolve_status(raw_status, default:)
    if raw_status.blank?
      return default unless default.nil?

      render_error("validation_error", "status is invalid", :unprocessable_entity)
      return nil
    end

    status = raw_status.to_s
    return status if Reservation.statuses.key?(status)

    render_error("validation_error", "status is invalid", :unprocessable_entity)
    nil
  end

  def render_invalid_status_error(_exception)
    render_error("validation_error", "status is invalid", :unprocessable_entity)
  end
end
