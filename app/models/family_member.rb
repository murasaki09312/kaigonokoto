class FamilyMember < ApplicationRecord
  belongs_to :tenant
  belongs_to :client
  has_many :notification_logs, dependent: :nullify

  scope :active, -> { where(active: true) }
  scope :line_enabled, -> { where(line_enabled: true).where.not(line_user_id: [ nil, "" ]) }
  scope :line_recipients_for, ->(client_id) { active.line_enabled.where(client_id: client_id).order(primary_contact: :desc, id: :asc) }

  validates :name, presence: true
  validates :line_user_id, presence: true, if: :line_enabled?
  validates :line_user_id, uniqueness: { scope: :tenant_id }, allow_blank: true
  validate :client_belongs_to_tenant

  before_validation :normalize_line_user_id

  private

  def normalize_line_user_id
    self.line_user_id = line_user_id.to_s.strip.presence
  end

  def client_belongs_to_tenant
    return if client.blank?
    return if tenant_id == client.tenant_id

    errors.add(:client_id, "must belong to the same tenant")
  end
end
