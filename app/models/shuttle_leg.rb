class ShuttleLeg < ApplicationRecord
  belongs_to :tenant
  belongs_to :shuttle_operation
  belongs_to :handled_by_user, class_name: "User", optional: true

  enum :direction, {
    pickup: 0,
    dropoff: 1
  }, prefix: true

  enum :status, {
    pending: 0,
    boarded: 1,
    alighted: 2,
    cancelled: 3
  }, prefix: true

  validates :direction, presence: true
  validates :status, presence: true
  validates :shuttle_operation_id, uniqueness: { scope: [ :tenant_id, :direction ] }
  validate :shuttle_operation_belongs_to_tenant
  validate :handled_by_user_belongs_to_tenant
  validate :status_allowed_for_direction

  private

  def shuttle_operation_belongs_to_tenant
    return if tenant_id.blank? || shuttle_operation_id.blank?
    return if shuttle_operation.blank?
    return if shuttle_operation.tenant_id == tenant_id

    errors.add(:shuttle_operation_id, "must belong to the same tenant")
  end

  def handled_by_user_belongs_to_tenant
    return if handled_by_user_id.blank? || tenant_id.blank?
    return if handled_by_user.blank?
    return if handled_by_user.tenant_id == tenant_id

    errors.add(:handled_by_user_id, "must belong to the same tenant")
  end

  def status_allowed_for_direction
    return if direction.blank? || status.blank?
    return if direction_pickup? && !status_alighted?
    return if direction_dropoff? && !status_boarded?

    errors.add(:status, "is invalid for direction")
  end
end
