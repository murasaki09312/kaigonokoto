class AddBreakdownAmountsToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :insurance_claim_amount, :integer, null: false, default: 0
    add_column :invoices, :insured_copayment_amount, :integer, null: false, default: 0
    add_column :invoices, :excess_copayment_amount, :integer, null: false, default: 0
  end
end
