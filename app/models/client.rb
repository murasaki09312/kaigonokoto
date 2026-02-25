class Client < ApplicationRecord
  belongs_to :tenant
  has_many :contracts, dependent: :destroy
  has_many :reservations, dependent: :destroy
  has_many :shuttle_operations, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_many :family_members, dependent: :destroy
  has_many :notification_logs, dependent: :restrict_with_exception

  enum :gender, { unknown: 0, male: 1, female: 2, other: 3 }, prefix: true
  enum :status, { active: 0, inactive: 1 }, prefix: true

  PHONE_FORMAT = /\A[0-9+\-() ]+\z/

  validates :name, presence: true
  validates :phone, format: { with: PHONE_FORMAT }, allow_blank: true
  validates :emergency_contact_phone, format: { with: PHONE_FORMAT }, allow_blank: true
end
