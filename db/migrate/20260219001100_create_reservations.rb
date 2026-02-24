class CreateReservations < ActiveRecord::Migration[8.0]
  def change
    create_table :reservations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.date :service_date, null: false
      t.time :start_time
      t.time :end_time
      t.integer :status, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :reservations, [ :tenant_id, :service_date ]
    add_index :reservations, [ :tenant_id, :client_id, :service_date ]
  end
end
