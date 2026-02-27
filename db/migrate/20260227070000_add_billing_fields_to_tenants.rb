class AddBillingFieldsToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :city_name, :string
    add_column :tenants, :facility_scale, :integer

    add_index :tenants, :city_name
    add_index :tenants, :facility_scale
  end
end
