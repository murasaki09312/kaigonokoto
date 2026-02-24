class CreateShuttleLegs < ActiveRecord::Migration[8.1]
  def change
    create_table :shuttle_legs do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :shuttle_operation, null: false, foreign_key: true
      t.integer :direction, null: false
      t.integer :status, null: false, default: 0
      t.datetime :planned_at
      t.datetime :actual_at
      t.references :handled_by_user, foreign_key: { to_table: :users }
      t.text :note

      t.timestamps
    end

    add_index :shuttle_legs, [ :tenant_id, :shuttle_operation_id, :direction ], unique: true, name: "index_shuttle_legs_on_tenant_op_direction"
    add_index :shuttle_legs, [ :tenant_id, :direction, :status ]
    add_index :shuttle_legs, [ :tenant_id, :actual_at ]

    add_check_constraint :shuttle_legs,
      "(direction = 0 AND status IN (0, 1, 3)) OR (direction = 1 AND status IN (0, 2, 3))",
      name: "shuttle_legs_direction_status_compatibility"
  end
end
