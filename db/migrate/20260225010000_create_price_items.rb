class CreatePriceItems < ActiveRecord::Migration[8.1]
  def change
    create_table :price_items do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.integer :unit_price, null: false
      t.integer :billing_unit, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.date :valid_from
      t.date :valid_to

      t.timestamps
    end

    add_index :price_items, [ :tenant_id, :code ], unique: true
    add_index :price_items, [ :tenant_id, :active ]
  end
end
