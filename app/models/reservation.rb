class Reservation < ApplicationRecord
  belongs_to :tenant
  belongs_to :client

  enum :status, {
    scheduled: 0,
    cancelled: 1,
    completed: 2
  }, prefix: true

  scope :within_dates, ->(from, to) { where(service_date: from..to) }
  scope :scheduled_on, ->(date) { where(service_date: date, status: statuses.fetch("scheduled")) }
  scope :in_display_order, -> { order(:service_date, :start_time, :created_at) }

  validates :service_date, presence: true
  validate :end_time_after_start_time
  validate :client_belongs_to_tenant

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    return if end_time > start_time

    errors.add(:end_time, "must be after start_time")
  end

  def client_belongs_to_tenant
    return if tenant_id.blank? || client_id.blank?
    return if client.blank?
    return if client.tenant_id == tenant_id

    errors.add(:client_id, "must belong to the same tenant")
  end
end
