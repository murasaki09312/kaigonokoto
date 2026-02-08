class Tenant < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception
  has_many :clients, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
end
