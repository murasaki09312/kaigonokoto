class Contract < ApplicationRecord
  OPEN_ENDED_DATE = Date.new(9999, 12, 31)
  ALLOWED_WEEKDAYS = (0..6).to_a.freeze

  belongs_to :tenant
  belongs_to :client

  scope :recent_first, -> { order(start_on: :desc, created_at: :desc) }
  scope :active_on, ->(date) { where("start_on <= ? AND COALESCE(end_on, ?) >= ?", date, OPEN_ENDED_DATE, date) }

  before_validation :normalize_weekdays
  before_validation :normalize_services

  validates :start_on, presence: true
  validates :weekdays, presence: true
  validates :weekdays, length: { minimum: 1 }
  validates :shuttle_required, inclusion: { in: [ true, false ] }
  validate :end_on_after_start_on
  validate :weekdays_must_be_valid
  validate :services_must_be_hash
  validate :client_belongs_to_tenant
  validate :period_must_not_overlap

  private

  def normalize_weekdays
    self.weekdays = Array(weekdays).filter_map do |value|
      next if value.blank?

      Integer(value, exception: false)
    end.uniq.sort
  end

  def normalize_services
    if services.blank?
      self.services = {}
      return
    end

    if services.respond_to?(:to_unsafe_h)
      self.services = services.to_unsafe_h.stringify_keys
    elsif services.is_a?(Hash)
      self.services = services.stringify_keys
    end
  end

  def end_on_after_start_on
    return if start_on.blank? || end_on.blank?
    return if end_on >= start_on

    errors.add(:end_on, "must be on or after start_on")
  end

  def services_must_be_hash
    return if services.is_a?(Hash)

    errors.add(:services, "must be an object")
  end

  def weekdays_must_be_valid
    return if weekdays.blank?
    return if weekdays.all? { |weekday| ALLOWED_WEEKDAYS.include?(weekday) }

    errors.add(:weekdays, "contains invalid weekday values")
  end

  def client_belongs_to_tenant
    return if tenant_id.blank? || client_id.blank?
    return if client.blank?
    return if client.tenant_id == tenant_id

    errors.add(:client_id, "must belong to the same tenant")
  end

  def period_must_not_overlap
    return if tenant_id.blank? || client_id.blank? || start_on.blank?

    overlap_relation = Contract.where(tenant_id: tenant_id, client_id: client_id)
    overlap_relation = overlap_relation.where.not(id: id) if persisted?

    return unless overlap_relation.where("start_on <= ? AND COALESCE(end_on, ?) >= ?", effective_end_on, OPEN_ENDED_DATE, start_on).exists?

    errors.add(:base, "Contract period overlaps with existing contracts")
  end

  def effective_end_on
    end_on || OPEN_ENDED_DATE
  end
end
