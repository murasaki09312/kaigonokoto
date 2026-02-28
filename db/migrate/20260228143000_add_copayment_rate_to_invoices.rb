class AddCopaymentRateToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :copayment_rate, :integer, null: false, default: 1
    add_check_constraint :invoices, "copayment_rate IN (1, 2, 3)", name: "invoices_copayment_rate_range"
  end
end
