class Attendance < ApplicationRecord
  belongs_to :tenant
  belongs_to :reservation

  enum :status, {
    pending: 0,
    present: 1,
    absent: 2,
    cancelled: 3
  }, prefix: true

  validates :status, presence: true
  validates :reservation_id, uniqueness: { scope: :tenant_id }
  validate :reservation_belongs_to_tenant

  private

  def reservation_belongs_to_tenant
    return if tenant_id.blank? || reservation_id.blank?
    return if reservation.blank?
    return if reservation.tenant_id == tenant_id

    errors.add(:reservation_id, "must belong to the same tenant")
  end
end
