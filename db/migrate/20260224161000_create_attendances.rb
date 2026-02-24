class CreateAttendances < ActiveRecord::Migration[8.1]
  def change
    create_table :attendances do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :reservation, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.text :absence_reason
      t.datetime :contacted_at
      t.text :note

      t.timestamps
    end

    add_index :attendances, [ :tenant_id, :reservation_id ], unique: true
    add_index :attendances, [ :tenant_id, :status ]
  end
end
