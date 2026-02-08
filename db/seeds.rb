tenant = Tenant.find_or_create_by!(slug: "demo-dayservice") do |record|
  record.name = "Demo Dayservice"
end
tenant.update!(name: "Demo Dayservice") if tenant.name != "Demo Dayservice"

permission_keys = [
  "users:read",
  "users:manage",
  "tenants:manage",
  "system:audit_read"
]

permissions = permission_keys.to_h do |key|
  [key, Permission.find_or_create_by!(key: key)]
end

admin_role = Role.find_or_create_by!(name: "admin")
staff_role = Role.find_or_create_by!(name: "staff")

admin_role.permissions = permissions.values
staff_role.permissions = [permissions.fetch("users:read")]

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
