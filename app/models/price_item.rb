class PriceItem < ApplicationRecord
  belongs_to :tenant

  has_many :invoice_lines, dependent: :restrict_with_exception

  enum :billing_unit, {
    per_use: 0
  }, prefix: true

  validates :code, presence: true, uniqueness: { scope: :tenant_id }
  validates :name, presence: true
  validates :unit_price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }
  validate :valid_to_after_valid_from

  scope :active_for, ->(date) {
    where(active: true)
      .where("COALESCE(valid_from, ?) <= ?", Date.new(1900, 1, 1), date)
      .where("COALESCE(valid_to, ?) >= ?", Date.new(9999, 12, 31), date)
  }

  private

  def valid_to_after_valid_from
    return if valid_from.blank? || valid_to.blank?
    return if valid_to >= valid_from

    errors.add(:valid_to, "must be on or after valid_from")
  end
end
