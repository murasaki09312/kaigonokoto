class CreateCareRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :care_records do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :reservation, null: false, foreign_key: true
      t.references :recorded_by_user, foreign_key: { to_table: :users }
      t.decimal :body_temperature, precision: 4, scale: 1
      t.integer :systolic_bp
      t.integer :diastolic_bp
      t.integer :pulse
      t.integer :spo2
      t.text :care_note
      t.text :handoff_note

      t.timestamps
    end

    add_index :care_records, [ :tenant_id, :reservation_id ], unique: true
    add_index :care_records, [ :tenant_id, :updated_at ]
  end
end
