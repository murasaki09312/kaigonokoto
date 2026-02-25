class NotificationLog < ApplicationRecord
  belongs_to :tenant
  belongs_to :client
  belongs_to :family_member, optional: true

  enum :channel, { line: 0 }, prefix: true
  enum :status, { queued: 0, sent: 1, failed: 2, skipped: 3 }, prefix: true

  validates :event_name, presence: true
  validates :source_type, presence: true
  validates :source_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :idempotency_key, presence: true, uniqueness: { scope: :tenant_id }
  validate :client_belongs_to_tenant
  validate :family_member_belongs_to_tenant
  validate :family_member_belongs_to_client

  private

  def client_belongs_to_tenant
    return if client.blank?
    return if tenant_id == client.tenant_id

    errors.add(:client_id, "must belong to the same tenant")
  end

  def family_member_belongs_to_tenant
    return if family_member.blank?
    return if tenant_id == family_member.tenant_id

    errors.add(:family_member_id, "must belong to the same tenant")
  end

  def family_member_belongs_to_client
    return if family_member.blank? || client.blank?
    return if family_member.client_id == client_id

    errors.add(:family_member_id, "must belong to the same client")
  end
end
