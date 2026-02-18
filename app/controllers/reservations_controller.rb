class ReservationsController < ApplicationController
  before_action :set_reservation, only: [:show, :update, :destroy]

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
    client = current_tenant.clients.find(reservation_params.fetch(:client_id))

    reservation = current_tenant.reservations.new(
      reservation_params.except(:force).merge(client: client)
    )

    if scheduled_status?(reservation.status) && capacity_exceeded_on?(reservation.service_date) && !force_override_allowed?
      return render_capacity_exceeded([reservation.service_date])
    end

    if reservation.save
      render json: { reservation: reservation_response(reservation) }, status: :created
    else
      render_validation_error(reservation)
    end
  end

  def update
    authorize @reservation, :update?, policy_class: ReservationPolicy
    attrs = reservation_params.except(:force)
    attrs[:client] = current_tenant.clients.find(attrs.delete(:client_id)) if attrs.key?(:client_id)

    @reservation.assign_attributes(attrs)

    if scheduled_status?(@reservation.status) &&
      capacity_exceeded_on?(@reservation.service_date, exclude_id: @reservation.id) &&
      !force_override_allowed?
      return render_capacity_exceeded([@reservation.service_date])
    end

    if @reservation.save
      render json: { reservation: reservation_response(@reservation) }, status: :ok
    else
      render_validation_error(@reservation)
    end
  end

  def destroy
    authorize @reservation, :destroy?, policy_class: ReservationPolicy
    @reservation.destroy!

    head :no_content
  end

  def generate
    authorize Reservation, :generate?, policy_class: ReservationPolicy
    client = current_tenant.clients.find(generate_params.fetch(:client_id))
    start_on = parse_iso_date(generate_params.fetch(:start_on), "start_on")
    end_on = parse_iso_date(generate_params.fetch(:end_on), "end_on")
    return if performed?

    weekdays = normalize_weekdays(generate_params[:weekdays])
    return if performed?
    if end_on < start_on
      return render_error("validation_error", "end_on must be on or after start_on", :unprocessable_entity)
    end

    target_dates = (start_on..end_on).select { |date| weekdays.include?(date.wday) }
    if target_dates.empty?
      return render_error("validation_error", "No dates match the selected weekdays", :unprocessable_entity)
    end

    target_status = generate_params[:status].presence || "scheduled"
    conflicts = if scheduled_status?(target_status)
      target_dates.select { |date| capacity_exceeded_on?(date) }
    else
      []
    end
    if conflicts.any? && !force_override_allowed?
      return render_capacity_exceeded(conflicts)
    end

    reservations = []
    ActiveRecord::Base.transaction do
      target_dates.each do |date|
        reservations << current_tenant.reservations.create!(
          client: client,
          service_date: date,
          start_time: generate_params[:start_time],
          end_time: generate_params[:end_time],
          notes: generate_params[:notes],
          status: target_status
        )
      end
    end

    render json: {
      reservations: reservations.map { |reservation| reservation_response(reservation) },
      meta: {
        total: reservations.size,
        conflicts: conflicts
      }
    }, status: :created
  rescue ActiveRecord::RecordInvalid => exception
    render_validation_error(exception.record)
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
      :client_id,
      :start_on,
      :end_on,
      :start_time,
      :end_time,
      :status,
      :notes,
      :force,
      weekdays: []
    )
  end

  def parse_range_params
    from = params[:from].present? ? parse_iso_date(params[:from], "from") : Date.current
    to = params[:to].present? ? parse_iso_date(params[:to], "to") : from
    return [from, to] if performed?
    return [from, to] if to >= from

    render_error("bad_request", "to must be on or after from", :bad_request)
    [nil, nil]
  end

  def parse_iso_date(value, field_name)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    render_error("bad_request", "#{field_name} must be ISO date (YYYY-MM-DD)", :bad_request)
    nil
  end

  def normalize_weekdays(raw_weekdays)
    weekdays = Array(raw_weekdays).filter_map { |value| Integer(value, exception: false) }.uniq.sort
    return weekdays if weekdays.present? && weekdays.all? { |weekday| weekday.between?(0, 6) }

    render_error("validation_error", "weekdays must include values between 0 and 6", :unprocessable_entity)
    []
  end

  def scheduled_status?(status)
    status.to_s == "scheduled"
  end

  def force_override_allowed?
    return false unless ActiveModel::Type::Boolean.new.cast(params[:force])

    ReservationPolicy.new(current_user, Reservation).override_capacity?
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
end
