class CreateClients < ActiveRecord::Migration[8.0]
  def change
    create_table :clients do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kana
      t.date :birth_date
      t.integer :gender, null: false, default: 0
      t.string :phone
      t.string :address
      t.string :emergency_contact_name
      t.string :emergency_contact_phone
      t.text :notes
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :clients, [:tenant_id, :name]
    add_index :clients, [:tenant_id, :status]
  end
end
