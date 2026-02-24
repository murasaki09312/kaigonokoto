class Tenant < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception
  has_many :clients, dependent: :restrict_with_exception
  has_many :contracts, dependent: :restrict_with_exception
  has_many :reservations, dependent: :restrict_with_exception
  has_many :attendances, dependent: :restrict_with_exception
  has_many :care_records, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :capacity_per_day, numericality: { only_integer: true, greater_than: 0 }
end
