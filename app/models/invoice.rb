class Invoice < ApplicationRecord
  belongs_to :tenant
  belongs_to :client
  belongs_to :generated_by_user, class_name: "User", optional: true

  has_many :invoice_lines, dependent: :destroy

  enum :status, {
    draft: 0,
    fixed: 1
  }, prefix: true

  validates :billing_month, presence: true
  validates :status, presence: true
  validates :subtotal_amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :total_amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :client_id, uniqueness: { scope: [ :tenant_id, :billing_month ] }
  validate :billing_month_must_be_month_start
  validate :client_belongs_to_tenant
  validate :generated_by_user_belongs_to_tenant

  scope :for_month, ->(month_start) { where(billing_month: month_start) }
  scope :in_display_order, -> { joins(:client).order("clients.name ASC", "invoices.created_at ASC") }

  def recalculate_totals!
    sum = invoice_lines.sum(:line_total)
    self.subtotal_amount = sum
    self.total_amount = sum
  end

  private

  def billing_month_must_be_month_start
    return if billing_month.blank?
    return if billing_month == billing_month.beginning_of_month

    errors.add(:billing_month, "must be the first day of month")
  end

  def client_belongs_to_tenant
    return if tenant_id.blank? || client_id.blank?
    return if client.blank?
    return if client.tenant_id == tenant_id

    errors.add(:client_id, "must belong to the same tenant")
  end

  def generated_by_user_belongs_to_tenant
    return if generated_by_user_id.blank? || tenant_id.blank?
    return if generated_by_user.blank?
    return if generated_by_user.tenant_id == tenant_id

    errors.add(:generated_by_user_id, "must belong to the same tenant")
  end
end
