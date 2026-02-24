class InvoiceLine < ApplicationRecord
  belongs_to :tenant
  belongs_to :invoice
  belongs_to :attendance, optional: true
  belongs_to :price_item, optional: true

  validates :item_name, presence: true
  validates :service_date, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :line_total, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :attendance_id, uniqueness: { scope: :tenant_id }, allow_nil: true
  validate :invoice_belongs_to_tenant
  validate :attendance_belongs_to_tenant
  validate :price_item_belongs_to_tenant

  private

  def invoice_belongs_to_tenant
    return if tenant_id.blank? || invoice_id.blank?
    return if invoice.blank?
    return if invoice.tenant_id == tenant_id

    errors.add(:invoice_id, "must belong to the same tenant")
  end

  def attendance_belongs_to_tenant
    return if attendance_id.blank? || tenant_id.blank?
    return if attendance.blank?
    return if attendance.tenant_id == tenant_id

    errors.add(:attendance_id, "must belong to the same tenant")
  end

  def price_item_belongs_to_tenant
    return if price_item_id.blank? || tenant_id.blank?
    return if price_item.blank?
    return if price_item.tenant_id == tenant_id

    errors.add(:price_item_id, "must belong to the same tenant")
  end
end
