class Client < ApplicationRecord
  belongs_to :tenant

  enum :gender, { unknown: 0, male: 1, female: 2, other: 3 }, prefix: true
  enum :status, { active: 0, inactive: 1 }, prefix: true

  PHONE_FORMAT = /\A[0-9+\-() ]+\z/

  validates :name, presence: true
  validates :phone, format: { with: PHONE_FORMAT }, allow_blank: true
  validates :emergency_contact_phone, format: { with: PHONE_FORMAT }, allow_blank: true
end
