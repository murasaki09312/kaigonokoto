class CreateNotificationLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_logs do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.references :family_member, foreign_key: { on_delete: :nullify }, null: true
      t.string :event_name, null: false
      t.string :source_type, null: false
      t.bigint :source_id, null: false
      t.integer :channel, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.text :message_body
      t.string :provider_message_id
      t.string :error_code
      t.text :error_message
      t.string :idempotency_key, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :notification_logs, [ :tenant_id, :idempotency_key ], unique: true
    add_index :notification_logs, [ :tenant_id, :source_type, :source_id ]
    add_index :notification_logs, [ :tenant_id, :status, :created_at ]
  end
end
