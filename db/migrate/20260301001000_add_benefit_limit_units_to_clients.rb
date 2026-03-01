class AddBenefitLimitUnitsToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :benefit_limit_units, :integer
    add_check_constraint :clients, "benefit_limit_units IS NULL OR benefit_limit_units >= 0", name: "clients_benefit_limit_units_non_negative"
  end
end
