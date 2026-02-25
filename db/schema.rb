# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_26_010310) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"

  create_table "attendances", force: :cascade do |t|
    t.text "absence_reason"
    t.datetime "contacted_at"
    t.datetime "created_at", null: false
    t.text "note"
    t.bigint "reservation_id", null: false
    t.integer "status", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["reservation_id"], name: "index_attendances_on_reservation_id"
    t.index ["tenant_id", "reservation_id"], name: "index_attendances_on_tenant_id_and_reservation_id", unique: true
    t.index ["tenant_id", "status"], name: "index_attendances_on_tenant_id_and_status"
    t.index ["tenant_id"], name: "index_attendances_on_tenant_id"
  end

  create_table "care_records", force: :cascade do |t|
    t.decimal "body_temperature", precision: 4, scale: 1
    t.text "care_note"
    t.datetime "created_at", null: false
    t.integer "diastolic_bp"
    t.text "handoff_note"
    t.integer "pulse"
    t.bigint "recorded_by_user_id"
    t.bigint "reservation_id", null: false
    t.integer "spo2"
    t.integer "systolic_bp"
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recorded_by_user_id"], name: "index_care_records_on_recorded_by_user_id"
    t.index ["reservation_id"], name: "index_care_records_on_reservation_id"
    t.index ["tenant_id", "reservation_id"], name: "index_care_records_on_tenant_id_and_reservation_id", unique: true
    t.index ["tenant_id", "updated_at"], name: "index_care_records_on_tenant_id_and_updated_at"
    t.index ["tenant_id"], name: "index_care_records_on_tenant_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "address"
    t.date "birth_date"
    t.datetime "created_at", null: false
    t.string "emergency_contact_name"
    t.string "emergency_contact_phone"
    t.integer "gender", default: 0, null: false
    t.string "kana"
    t.string "name", null: false
    t.text "notes"
    t.string "phone"
    t.integer "status", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "name"], name: "index_clients_on_tenant_id_and_name"
    t.index ["tenant_id", "status"], name: "index_clients_on_tenant_id_and_status"
    t.index ["tenant_id"], name: "index_clients_on_tenant_id"
  end

  create_table "contracts", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.date "end_on"
    t.text "service_note"
    t.jsonb "services", default: {}, null: false
    t.text "shuttle_note"
    t.boolean "shuttle_required", default: false, null: false
    t.date "start_on", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.integer "weekdays", default: [], null: false, array: true
    t.index ["client_id"], name: "index_contracts_on_client_id"
    t.index ["tenant_id", "client_id", "end_on"], name: "index_contracts_on_tenant_id_and_client_id_and_end_on"
    t.index ["tenant_id", "client_id", "start_on"], name: "index_contracts_on_tenant_id_and_client_id_and_start_on"
    t.index ["tenant_id"], name: "index_contracts_on_tenant_id"
    t.exclusion_constraint "tenant_id WITH =, client_id WITH =, daterange(start_on, COALESCE((end_on + 1), 'infinity'::date), '[)'::text) WITH &&", using: :gist, name: "contracts_no_overlapping_periods"
  end

  create_table "family_members", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.boolean "line_enabled", default: false, null: false
    t.string "line_user_id"
    t.string "name", null: false
    t.boolean "primary_contact", default: false, null: false
    t.string "relationship"
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_family_members_on_client_id"
    t.index ["tenant_id", "active"], name: "index_family_members_on_tenant_id_and_active"
    t.index ["tenant_id", "client_id"], name: "index_family_members_on_tenant_id_and_client_id"
    t.index ["tenant_id", "line_user_id"], name: "index_family_members_on_tenant_and_line_user_id", unique: true, where: "((line_user_id IS NOT NULL) AND (btrim((line_user_id)::text) <> ''::text))"
    t.index ["tenant_id"], name: "index_family_members_on_tenant_id"
    t.check_constraint "NOT line_enabled OR line_user_id IS NOT NULL AND btrim(line_user_id::text) <> ''::text", name: "family_members_line_enabled_requires_line_user_id"
  end

  create_table "invoice_lines", force: :cascade do |t|
    t.bigint "attendance_id"
    t.datetime "created_at", null: false
    t.bigint "invoice_id", null: false
    t.string "item_name", null: false
    t.integer "line_total", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "price_item_id"
    t.decimal "quantity", precision: 8, scale: 2, default: "1.0", null: false
    t.date "service_date", null: false
    t.bigint "tenant_id", null: false
    t.integer "unit_price", null: false
    t.datetime "updated_at", null: false
    t.index ["attendance_id"], name: "index_invoice_lines_on_attendance_id"
    t.index ["invoice_id"], name: "index_invoice_lines_on_invoice_id"
    t.index ["price_item_id"], name: "index_invoice_lines_on_price_item_id"
    t.index ["tenant_id", "attendance_id"], name: "index_invoice_lines_on_tenant_id_and_attendance_id", unique: true, where: "(attendance_id IS NOT NULL)"
    t.index ["tenant_id", "invoice_id"], name: "index_invoice_lines_on_tenant_id_and_invoice_id"
    t.index ["tenant_id", "service_date"], name: "index_invoice_lines_on_tenant_id_and_service_date"
    t.index ["tenant_id"], name: "index_invoice_lines_on_tenant_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.date "billing_month", null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "generated_at"
    t.bigint "generated_by_user_id"
    t.integer "status", default: 0, null: false
    t.integer "subtotal_amount", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.integer "total_amount", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_invoices_on_client_id"
    t.index ["generated_by_user_id"], name: "index_invoices_on_generated_by_user_id"
    t.index ["tenant_id", "billing_month"], name: "index_invoices_on_tenant_id_and_billing_month"
    t.index ["tenant_id", "client_id", "billing_month"], name: "index_invoices_on_tenant_id_and_client_id_and_billing_month", unique: true
    t.index ["tenant_id", "status"], name: "index_invoices_on_tenant_id_and_status"
    t.index ["tenant_id"], name: "index_invoices_on_tenant_id"
  end

  create_table "notification_logs", force: :cascade do |t|
    t.integer "channel", default: 0, null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.string "error_code"
    t.text "error_message"
    t.string "event_name", null: false
    t.bigint "family_member_id"
    t.string "idempotency_key", null: false
    t.text "message_body"
    t.jsonb "metadata", default: {}, null: false
    t.string "provider_message_id"
    t.bigint "source_id", null: false
    t.string "source_type", null: false
    t.integer "status", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_notification_logs_on_client_id"
    t.index ["family_member_id"], name: "index_notification_logs_on_family_member_id"
    t.index ["tenant_id", "idempotency_key"], name: "index_notification_logs_on_tenant_id_and_idempotency_key", unique: true
    t.index ["tenant_id", "source_type", "source_id"], name: "idx_on_tenant_id_source_type_source_id_fe8d782863"
    t.index ["tenant_id", "status", "created_at"], name: "index_notification_logs_on_tenant_id_and_status_and_created_at"
    t.index ["tenant_id"], name: "index_notification_logs_on_tenant_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
  end

  create_table "price_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "billing_unit", default: 0, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "tenant_id", null: false
    t.integer "unit_price", null: false
    t.datetime "updated_at", null: false
    t.date "valid_from"
    t.date "valid_to"
    t.index ["tenant_id", "active"], name: "index_price_items_on_tenant_id_and_active"
    t.index ["tenant_id", "code"], name: "index_price_items_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_price_items_on_tenant_id"
  end

  create_table "reservations", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.time "end_time"
    t.text "notes"
    t.date "service_date", null: false
    t.time "start_time"
    t.integer "status", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_reservations_on_client_id"
    t.index ["tenant_id", "client_id", "service_date"], name: "index_reservations_on_tenant_id_and_client_id_and_service_date"
    t.index ["tenant_id", "service_date"], name: "index_reservations_on_tenant_id_and_service_date"
    t.index ["tenant_id"], name: "index_reservations_on_tenant_id"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "permission_id", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "shuttle_legs", force: :cascade do |t|
    t.datetime "actual_at"
    t.datetime "created_at", null: false
    t.integer "direction", null: false
    t.bigint "handled_by_user_id"
    t.text "note"
    t.datetime "planned_at"
    t.bigint "shuttle_operation_id", null: false
    t.integer "status", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["handled_by_user_id"], name: "index_shuttle_legs_on_handled_by_user_id"
    t.index ["shuttle_operation_id"], name: "index_shuttle_legs_on_shuttle_operation_id"
    t.index ["tenant_id", "actual_at"], name: "index_shuttle_legs_on_tenant_id_and_actual_at"
    t.index ["tenant_id", "direction", "status"], name: "index_shuttle_legs_on_tenant_id_and_direction_and_status"
    t.index ["tenant_id", "shuttle_operation_id", "direction"], name: "index_shuttle_legs_on_tenant_op_direction", unique: true
    t.index ["tenant_id"], name: "index_shuttle_legs_on_tenant_id"
    t.check_constraint "direction = 0 AND (status = ANY (ARRAY[0, 1, 3])) OR direction = 1 AND (status = ANY (ARRAY[0, 2, 3]))", name: "shuttle_legs_direction_status_compatibility"
  end

  create_table "shuttle_operations", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.boolean "requires_dropoff", default: true, null: false
    t.boolean "requires_pickup", default: true, null: false
    t.bigint "reservation_id", null: false
    t.date "service_date", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_shuttle_operations_on_client_id"
    t.index ["reservation_id"], name: "index_shuttle_operations_on_reservation_id"
    t.index ["tenant_id", "client_id", "service_date"], name: "idx_on_tenant_id_client_id_service_date_9401eb1ac4"
    t.index ["tenant_id", "reservation_id"], name: "index_shuttle_operations_on_tenant_id_and_reservation_id", unique: true
    t.index ["tenant_id", "service_date"], name: "index_shuttle_operations_on_tenant_id_and_service_date"
    t.index ["tenant_id"], name: "index_shuttle_operations_on_tenant_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.integer "capacity_per_day", default: 25, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
  end

  create_table "user_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "email"], name: "index_users_on_tenant_id_and_email", unique: true
    t.index ["tenant_id"], name: "index_users_on_tenant_id"
  end

  add_foreign_key "attendances", "reservations"
  add_foreign_key "attendances", "tenants"
  add_foreign_key "care_records", "reservations"
  add_foreign_key "care_records", "tenants"
  add_foreign_key "care_records", "users", column: "recorded_by_user_id"
  add_foreign_key "clients", "tenants"
  add_foreign_key "contracts", "clients"
  add_foreign_key "contracts", "tenants"
  add_foreign_key "family_members", "clients"
  add_foreign_key "family_members", "tenants"
  add_foreign_key "invoice_lines", "attendances"
  add_foreign_key "invoice_lines", "invoices"
  add_foreign_key "invoice_lines", "price_items"
  add_foreign_key "invoice_lines", "tenants"
  add_foreign_key "invoices", "clients"
  add_foreign_key "invoices", "tenants"
  add_foreign_key "invoices", "users", column: "generated_by_user_id"
  add_foreign_key "notification_logs", "clients"
  add_foreign_key "notification_logs", "family_members", on_delete: :nullify
  add_foreign_key "notification_logs", "tenants"
  add_foreign_key "price_items", "tenants"
  add_foreign_key "reservations", "clients"
  add_foreign_key "reservations", "tenants"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "shuttle_legs", "shuttle_operations"
  add_foreign_key "shuttle_legs", "tenants"
  add_foreign_key "shuttle_legs", "users", column: "handled_by_user_id"
  add_foreign_key "shuttle_operations", "clients"
  add_foreign_key "shuttle_operations", "reservations"
  add_foreign_key "shuttle_operations", "tenants"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "users", "tenants"
end
