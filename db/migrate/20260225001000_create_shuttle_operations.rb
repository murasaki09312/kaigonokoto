class CreateShuttleOperations < ActiveRecord::Migration[8.1]
  def change
    create_table :shuttle_operations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :reservation, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.date :service_date, null: false
      t.boolean :requires_pickup, null: false, default: true
      t.boolean :requires_dropoff, null: false, default: true

      t.timestamps
    end

    add_index :shuttle_operations, [ :tenant_id, :reservation_id ], unique: true
    add_index :shuttle_operations, [ :tenant_id, :service_date ]
    add_index :shuttle_operations, [ :tenant_id, :client_id, :service_date ]
  end
end
