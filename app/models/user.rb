class User < ApplicationRecord
  belongs_to :tenant

  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :permissions, through: :roles
  has_many :recorded_care_records, class_name: "CareRecord", foreign_key: :recorded_by_user_id, dependent: :nullify
  has_many :handled_shuttle_legs, class_name: "ShuttleLeg", foreign_key: :handled_by_user_id, dependent: :nullify

  has_secure_password

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: { scope: :tenant_id }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  def allowed?(permission_key)
    roles.joins(:permissions).where(permissions: { key: permission_key }).exists?
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
