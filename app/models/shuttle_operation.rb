class ShuttleOperation < ApplicationRecord
  belongs_to :tenant
  belongs_to :reservation
  belongs_to :client

  has_many :shuttle_legs, -> { order(:direction) }, dependent: :destroy

  validates :service_date, presence: true
  validates :reservation_id, uniqueness: { scope: :tenant_id }
  validates :requires_pickup, inclusion: { in: [ true, false ] }
  validates :requires_dropoff, inclusion: { in: [ true, false ] }
  validate :reservation_belongs_to_tenant
  validate :client_belongs_to_tenant
  validate :client_matches_reservation

  before_validation :sync_service_date_with_reservation

  def pickup_leg
    find_leg_by_direction("pickup")
  end

  def dropoff_leg
    find_leg_by_direction("dropoff")
  end

  private

  def find_leg_by_direction(direction)
    shuttle_legs.find { |leg| leg.direction == direction }
  end

  def sync_service_date_with_reservation
    self.service_date = reservation&.service_date if reservation_id.present?
  end

  def reservation_belongs_to_tenant
    return if tenant_id.blank? || reservation_id.blank?
    return if reservation.blank?
    return if reservation.tenant_id == tenant_id

    errors.add(:reservation_id, "must belong to the same tenant")
  end

  def client_belongs_to_tenant
    return if tenant_id.blank? || client_id.blank?
    return if client.blank?
    return if client.tenant_id == tenant_id

    errors.add(:client_id, "must belong to the same tenant")
  end

  def client_matches_reservation
    return if reservation.blank? || client_id.blank?
    return if reservation.client_id == client_id

    errors.add(:client_id, "must match reservation client")
  end
end
