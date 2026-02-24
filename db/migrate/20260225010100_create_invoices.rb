class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.date :billing_month, null: false
      t.integer :status, null: false, default: 0
      t.integer :subtotal_amount, null: false, default: 0
      t.integer :total_amount, null: false, default: 0
      t.datetime :generated_at
      t.references :generated_by_user, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :invoices, [ :tenant_id, :client_id, :billing_month ], unique: true
    add_index :invoices, [ :tenant_id, :billing_month ]
    add_index :invoices, [ :tenant_id, :status ]
  end
end
