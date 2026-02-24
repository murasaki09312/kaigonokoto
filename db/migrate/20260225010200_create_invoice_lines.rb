class CreateInvoiceLines < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_lines do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true
      t.references :attendance, foreign_key: true
      t.references :price_item, foreign_key: true
      t.date :service_date, null: false
      t.string :item_name, null: false
      t.decimal :quantity, null: false, default: 1.0, precision: 8, scale: 2
      t.integer :unit_price, null: false
      t.integer :line_total, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :invoice_lines, [ :tenant_id, :invoice_id ]
    add_index :invoice_lines, [ :tenant_id, :attendance_id ], unique: true, where: "attendance_id IS NOT NULL"
    add_index :invoice_lines, [ :tenant_id, :service_date ]
  end
end
