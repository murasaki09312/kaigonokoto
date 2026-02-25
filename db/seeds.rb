tenant = Tenant.find_or_create_by!(slug: "demo-dayservice") do |record|
  record.name = "Demo Dayservice"
end
tenant.update!(name: "Demo Dayservice") if tenant.name != "Demo Dayservice"

permission_keys = [
  "users:read",
  "users:manage",
  "clients:read",
  "clients:manage",
  "contracts:read",
  "contracts:manage",
  "today_board:read",
  "attendances:manage",
  "care_records:manage",
  "shuttles:read",
  "shuttles:manage",
  "invoices:read",
  "invoices:manage",
  "reservations:read",
  "reservations:manage",
  "reservations:override_capacity",
  "tenants:manage",
  "system:audit_read"
]

permissions = permission_keys.to_h do |key|
  [ key, Permission.find_or_create_by!(key: key) ]
end

admin_role = Role.find_or_create_by!(name: "admin")
staff_role = Role.find_or_create_by!(name: "staff")

admin_role.permissions = permissions.values
staff_role.permissions = [
  permissions.fetch("users:read"),
  permissions.fetch("clients:read"),
  permissions.fetch("contracts:read"),
  permissions.fetch("today_board:read"),
  permissions.fetch("attendances:manage"),
  permissions.fetch("care_records:manage"),
  permissions.fetch("shuttles:read"),
  permissions.fetch("invoices:read"),
  permissions.fetch("reservations:read")
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

admin_user.roles = [ admin_role ]
staff_user.roles = [ staff_role ]

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

sample_client = tenant.clients.find_by!(name: "山田 太郎")

sample_family_member = tenant.family_members.find_or_initialize_by(
  client: sample_client,
  name: "山田 家族"
)
sample_family_member.assign_attributes(
  relationship: "長男",
  line_user_id: "Udemo-family-#{sample_client.id}",
  line_enabled: true,
  active: true,
  primary_contact: true
)
sample_family_member.save!

contract_v1 = tenant.contracts.find_or_initialize_by(client_id: sample_client.id, start_on: Date.new(2025, 10, 1))
contract_v1.assign_attributes(
  end_on: Date.new(2025, 12, 31),
  weekdays: [ 1, 3, 5 ],
  services: { "meal" => true, "bath" => true, "rehabilitation" => false, "recreation" => true },
  service_note: "初期契約サンプル",
  shuttle_required: true,
  shuttle_note: "朝のみ送迎"
)
contract_v1.save!

contract_v2 = tenant.contracts.find_or_initialize_by(client_id: sample_client.id, start_on: Date.new(2026, 1, 1))
contract_v2.assign_attributes(
  end_on: nil,
  weekdays: [ 1, 2, 4 ],
  services: { "meal" => true, "bath" => false, "rehabilitation" => true, "recreation" => true },
  service_note: "冬季改定サンプル",
  shuttle_required: false,
  shuttle_note: nil
)
contract_v2.save!

tenant.update!(capacity_per_day: 25) if tenant.capacity_per_day != 25

price_item = tenant.price_items.find_or_initialize_by(code: "day_service_basic")
price_item.assign_attributes(
  name: "通所介護基本利用料",
  unit_price: 1200,
  billing_unit: :per_use,
  active: true,
  valid_from: Date.new(2026, 1, 1),
  valid_to: nil
)
price_item.save!

sample_dates = [ Date.current, Date.current + 1.day ]
sample_dates.each_with_index do |service_date, index|
  reservation = tenant.reservations.find_or_initialize_by(client_id: sample_client.id, service_date: service_date)
  reservation.assign_attributes(
    start_time: "09:30",
    end_time: "16:00",
    status: :scheduled,
    notes: index.zero? ? "定期利用サンプル" : "翌日利用サンプル"
  )
  reservation.save!
end

today_reservation = tenant.reservations.find_by(service_date: Date.current, client_id: sample_client.id)
if today_reservation
  attendance = tenant.attendances.find_or_initialize_by(reservation: today_reservation)
  attendance.assign_attributes(status: :present, note: "到着済みサンプル")
  attendance.save!

  care_record = tenant.care_records.find_or_initialize_by(reservation: today_reservation)
  care_record.assign_attributes(
    recorded_by_user: staff_user,
    body_temperature: 36.6,
    systolic_bp: 118,
    diastolic_bp: 72,
    pulse: 68,
    spo2: 98,
    care_note: "バイタル良好",
    handoff_note: "特記事項なし"
  )
  care_record.save!

  shuttle_operation = tenant.shuttle_operations.find_or_initialize_by(reservation: today_reservation)
  shuttle_operation.assign_attributes(
    client: today_reservation.client,
    service_date: today_reservation.service_date,
    requires_pickup: true,
    requires_dropoff: true
  )
  shuttle_operation.save!

  pickup_leg = shuttle_operation.shuttle_legs.find_or_initialize_by(direction: :pickup)
  pickup_leg.assign_attributes(
    tenant: tenant,
    status: :boarded,
    actual_at: Time.zone.now.change(hour: 9, min: 15),
    handled_by_user: staff_user,
    note: "玄関で乗車確認"
  )
  pickup_leg.save!

  dropoff_leg = shuttle_operation.shuttle_legs.find_or_initialize_by(direction: :dropoff)
  dropoff_leg.assign_attributes(
    tenant: tenant,
    status: :pending,
    handled_by_user: nil,
    actual_at: nil,
    note: nil
  )
  dropoff_leg.save!
end
