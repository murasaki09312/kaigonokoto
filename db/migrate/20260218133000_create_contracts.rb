class CreateContracts < ActiveRecord::Migration[8.0]
  def change
    create_table :contracts do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.date :start_on, null: false
      t.date :end_on
      t.integer :weekdays, array: true, default: [], null: false
      t.jsonb :services, default: {}, null: false
      t.text :service_note
      t.boolean :shuttle_required, default: false, null: false
      t.text :shuttle_note

      t.timestamps
    end

    add_index :contracts, [:tenant_id, :client_id, :start_on]
    add_index :contracts, [:tenant_id, :client_id, :end_on]
  end
end
