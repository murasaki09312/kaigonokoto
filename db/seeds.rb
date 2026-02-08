tenant = Tenant.find_or_create_by!(slug: "demo-dayservice") do |record|
  record.name = "Demo Dayservice"
end
tenant.update!(name: "Demo Dayservice") if tenant.name != "Demo Dayservice"

permission_keys = [
  "users:read",
  "users:manage",
  "clients:read",
  "clients:manage",
  "tenants:manage",
  "system:audit_read"
]

permissions = permission_keys.to_h do |key|
  [key, Permission.find_or_create_by!(key: key)]
end

admin_role = Role.find_or_create_by!(name: "admin")
staff_role = Role.find_or_create_by!(name: "staff")

admin_role.permissions = permissions.values
staff_role.permissions = [
  permissions.fetch("users:read"),
  permissions.fetch("clients:read")
]

admin_user = tenant.users.find_or_initialize_by(email: "admin@example.com")
admin_user.assign_attributes(
  name: "Admin User",
  password: "Password123!",
  password_confirmation: "Password123!"
)
admin_user.save!

staff_user = tenant.users.find_or_initialize_by(email: "staff@example.com")
staff_user.assign_attributes(
  name: "Staff User",
  password: "Password123!",
  password_confirmation: "Password123!"
)
staff_user.save!

admin_user.roles = [admin_role]
staff_user.roles = [staff_role]

tenant.clients.find_or_create_by!(name: "山田 太郎") do |client|
  client.kana = "ヤマダ タロウ"
  client.gender = :male
  client.phone = "090-1111-1111"
  client.status = :active
  client.notes = "サンプル利用者"
end

tenant.clients.find_or_create_by!(name: "佐藤 花子") do |client|
  client.kana = "サトウ ハナコ"
  client.gender = :female
  client.phone = "090-2222-2222"
  client.status = :inactive
  client.notes = "休止中サンプル"
end
