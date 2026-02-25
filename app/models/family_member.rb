class FamilyMember < ApplicationRecord
  INVITATION_TOKEN_BYTES = 24

  belongs_to :tenant
  belongs_to :client
  has_many :notification_logs, dependent: :nullify

  scope :active, -> { where(active: true) }
  scope :line_enabled, -> { where(line_enabled: true).where.not(line_user_id: [ nil, "" ]) }
  scope :line_recipients_for, ->(client_id) { active.line_enabled.where(client_id: client_id).order(primary_contact: :desc, id: :asc) }

  validates :name, presence: true
  validates :line_user_id, presence: true, if: :line_enabled?
  validates :line_user_id, uniqueness: { scope: :tenant_id }, allow_blank: true
  validates :line_invitation_token, uniqueness: true, allow_blank: true
  validate :client_belongs_to_tenant

  before_validation :normalize_line_user_id
  before_validation :normalize_line_invitation_token
  before_validation :clear_invitation_token_when_linked
  before_create :assign_unique_line_invitation_token, unless: :linked_to_line?
  before_create :set_line_invitation_token_generated_at, unless: -> { line_invitation_token.blank? }

  def linked_to_line?
    line_enabled? && line_user_id.present?
  end

  def ensure_line_invitation_token!(regenerate: false)
    return clear_line_invitation_token! if linked_to_line?
    return self if line_invitation_token.present? && !regenerate

    self.line_invitation_token = nil if regenerate
    assign_unique_line_invitation_token(force: regenerate)
    set_line_invitation_token_generated_at
    save! if changed?
    self
  end

  def clear_line_invitation_token!
    self.line_invitation_token = nil
    self.line_invitation_token_generated_at = nil
    save! if changed?
    self
  end

  private

  def normalize_line_user_id
    self.line_user_id = line_user_id.to_s.strip.presence
  end

  def normalize_line_invitation_token
    self.line_invitation_token = line_invitation_token.to_s.strip.presence
  end

  def clear_invitation_token_when_linked
    return unless linked_to_line?

    self.line_invitation_token = nil
    self.line_invitation_token_generated_at = nil
  end

  def assign_unique_line_invitation_token(force: false)
    return if line_invitation_token.present? && !force

    loop do
      candidate = SecureRandom.urlsafe_base64(INVITATION_TOKEN_BYTES)
      next if self.class.where(line_invitation_token: candidate).exists?

      self.line_invitation_token = candidate
      break
    end
  end

  def set_line_invitation_token_generated_at
    self.line_invitation_token_generated_at ||= Time.current
  end

  def client_belongs_to_tenant
    return if client.blank?
    return if tenant_id == client.tenant_id

    errors.add(:client_id, "must belong to the same tenant")
  end
end
