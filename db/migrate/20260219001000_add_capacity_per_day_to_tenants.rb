class AddCapacityPerDayToTenants < ActiveRecord::Migration[8.0]
  def change
    add_column :tenants, :capacity_per_day, :integer, null: false, default: 25
  end
end
