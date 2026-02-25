class CreateFamilyMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :family_members do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.string :name, null: false
      t.string :relationship
      t.string :line_user_id
      t.boolean :line_enabled, null: false, default: false
      t.boolean :active, null: false, default: true
      t.boolean :primary_contact, null: false, default: false

      t.timestamps
    end

    add_index :family_members, [ :tenant_id, :client_id ]
    add_index :family_members, [ :tenant_id, :active ]
    add_index :family_members, [ :tenant_id, :line_user_id ], unique: true,
      where: "line_user_id IS NOT NULL AND btrim(line_user_id) <> ''",
      name: "index_family_members_on_tenant_and_line_user_id"

    add_check_constraint :family_members,
      "(NOT line_enabled) OR (line_user_id IS NOT NULL AND btrim(line_user_id) <> '')",
      name: "family_members_line_enabled_requires_line_user_id"
  end
end
