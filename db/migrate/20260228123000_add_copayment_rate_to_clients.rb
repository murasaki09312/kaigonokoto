class AddCopaymentRateToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :copayment_rate, :integer, null: false, default: 1
    add_check_constraint :clients, "copayment_rate IN (1, 2, 3)", name: "clients_copayment_rate_range"
  end
end
