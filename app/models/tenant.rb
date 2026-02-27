class Tenant < ApplicationRecord
  enum :facility_scale, {
    normal: 0,
    large_1: 1,
    large_2: 2
  }, prefix: true

  has_many :users, dependent: :restrict_with_exception
  has_many :clients, dependent: :restrict_with_exception
  has_many :contracts, dependent: :restrict_with_exception
  has_many :reservations, dependent: :restrict_with_exception
  has_many :attendances, dependent: :restrict_with_exception
  has_many :care_records, dependent: :restrict_with_exception
  has_many :shuttle_operations, dependent: :restrict_with_exception
  has_many :shuttle_legs, dependent: :restrict_with_exception
  has_many :price_items, dependent: :restrict_with_exception
  has_many :invoices, dependent: :restrict_with_exception
  has_many :invoice_lines, dependent: :restrict_with_exception
  has_many :family_members, dependent: :restrict_with_exception
  has_many :notification_logs, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :capacity_per_day, numericality: { only_integer: true, greater_than: 0 }
  validates :facility_scale, inclusion: { in: facility_scales.keys }, allow_nil: true
end
