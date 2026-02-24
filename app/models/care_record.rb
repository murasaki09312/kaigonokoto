class CareRecord < ApplicationRecord
  belongs_to :tenant
  belongs_to :reservation
  belongs_to :recorded_by_user, class_name: "User", optional: true

  validates :reservation_id, uniqueness: { scope: :tenant_id }
  validates :body_temperature, numericality: { greater_than_or_equal_to: 30.0, less_than_or_equal_to: 45.0 }, allow_nil: true
  validates :systolic_bp, numericality: { greater_than_or_equal_to: 40, less_than_or_equal_to: 300 }, allow_nil: true
  validates :diastolic_bp, numericality: { greater_than_or_equal_to: 20, less_than_or_equal_to: 200 }, allow_nil: true
  validates :pulse, numericality: { greater_than_or_equal_to: 20, less_than_or_equal_to: 250 }, allow_nil: true
  validates :spo2, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validate :reservation_belongs_to_tenant
  validate :recorded_by_user_belongs_to_tenant

  private

  def reservation_belongs_to_tenant
    return if tenant_id.blank? || reservation_id.blank?
    return if reservation.blank?
    return if reservation.tenant_id == tenant_id

    errors.add(:reservation_id, "must belong to the same tenant")
  end

  def recorded_by_user_belongs_to_tenant
    return if recorded_by_user_id.blank? || tenant_id.blank?
    return if recorded_by_user.blank?
    return if recorded_by_user.tenant_id == tenant_id

    errors.add(:recorded_by_user_id, "must belong to the same tenant")
  end
end
