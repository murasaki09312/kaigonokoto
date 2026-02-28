tenant = Tenant.find_or_create_by!(slug: "demo-dayservice") do |record|
  record.name = "Demo Dayservice"
  record.city_name = "目黒区"
  record.facility_scale = :normal
end
tenant.update!(name: "Demo Dayservice") if tenant.name != "Demo Dayservice"
if tenant.city_name != "目黒区" || tenant.facility_scale != "normal"
  tenant.update!(city_name: "目黒区", facility_scale: :normal)
end

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
  "shuttles:operate",
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
driver_role = Role.find_or_create_by!(name: "driver")

admin_role.permissions = permissions.values
staff_role.permissions = [
  permissions.fetch("users:read"),
  permissions.fetch("clients:read"),
  permissions.fetch("contracts:read"),
  permissions.fetch("today_board:read"),
  permissions.fetch("attendances:manage"),
  permissions.fetch("care_records:manage"),
  permissions.fetch("shuttles:read"),
  permissions.fetch("shuttles:operate"),
  permissions.fetch("invoices:read"),
  permissions.fetch("reservations:read")
]

driver_role.permissions = [
  permissions.fetch("shuttles:read"),
  permissions.fetch("shuttles:operate")
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

driver_user = tenant.users.find_or_initialize_by(email: "driver@example.com")
driver_user.assign_attributes(
  name: "Driver User",
  password: "Password123!",
  password_confirmation: "Password123!"
)
driver_user.save!

admin_user.roles = [ admin_role ]
staff_user.roles = [ staff_role ]
driver_user.roles = [ driver_role ]

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

# -----------------------------------------------------------------------------
# Realistic billing demo seed (Tanaka case, February 2026)
# -----------------------------------------------------------------------------
billing_tenant = Tenant.find_or_create_by!(slug: "demo-billing-meguro-202602") do |record|
  record.name = "Billing Demo Meguro"
  record.city_name = "目黒区"
  record.facility_scale = :normal
end

if billing_tenant.name != "Billing Demo Meguro" ||
    billing_tenant.city_name != "目黒区" ||
    billing_tenant.facility_scale != "normal"
  billing_tenant.update!(
    name: "Billing Demo Meguro",
    city_name: "目黒区",
    facility_scale: :normal
  )
end

billing_admin = billing_tenant.users.find_or_initialize_by(email: "billing-admin@example.com")
billing_admin.assign_attributes(
  name: "Billing Admin",
  password: "Password123!",
  password_confirmation: "Password123!"
)
billing_admin.save!
billing_admin.roles = [ admin_role ]

tanaka_client = billing_tenant.clients.find_or_initialize_by(name: "田中 一郎")
tanaka_client.assign_attributes(
  kana: "タナカ イチロウ",
  gender: :male,
  phone: "090-3333-3333",
  status: :active,
  copayment_rate: 1,
  notes: "要介護1 / 限度額16,765単位 / 1割負担（デモケース）"
)
tanaka_client.save!

billing_month_start = Date.new(2026, 2, 1)
billing_month_end = billing_month_start.end_of_month
tanaka_service_dates = (billing_month_start..billing_month_end).reject(&:sunday?).first(22)

raise "Seed error: unable to prepare 22 service dates" if tanaka_service_dates.size < 22

# Idempotency: reset only the target month data for Tanaka scenario.
billing_tenant.invoices.where(client_id: tanaka_client.id, billing_month: billing_month_start).destroy_all
billing_tenant.reservations.where(client_id: tanaka_client.id, service_date: billing_month_start..billing_month_end).destroy_all
billing_tenant.contracts.where(client_id: tanaka_client.id).destroy_all

basic_price_item = billing_tenant.price_items.find_or_initialize_by(code: "day_service_basic")
basic_price_item.assign_attributes(
  name: "通所介護（7時間以上8時間未満）",
  unit_price: 658,
  billing_unit: :per_use,
  active: true,
  valid_from: Date.new(2026, 1, 1),
  valid_to: nil
)
basic_price_item.save!

bathing_price_item = billing_tenant.price_items.find_or_initialize_by(code: "day_service_bathing_1")
bathing_price_item.assign_attributes(
  name: "入浴介助加算I",
  unit_price: 40,
  billing_unit: :per_use,
  active: true,
  valid_from: Date.new(2026, 1, 1),
  valid_to: nil
)
bathing_price_item.save!

training_price_item = billing_tenant.price_items.find_or_initialize_by(code: "day_service_individual_training_1_ro")
training_price_item.assign_attributes(
  name: "個別機能訓練加算Iロ",
  unit_price: 76,
  billing_unit: :per_use,
  active: true,
  valid_from: Date.new(2026, 1, 1),
  valid_to: nil
)
training_price_item.save!

billing_tenant.contracts.create!(
  tenant: billing_tenant,
  client: tanaka_client,
  start_on: billing_month_start,
  end_on: nil,
  weekdays: [ 1, 2, 3, 4, 5, 6 ],
  services: {
    "meal" => true,
    "bath" => true,
    "rehabilitation" => true,
    "recreation" => false
  },
  service_note: "基本報酬 + 入浴介助加算I + 個別機能訓練加算Iロ（デモ）",
  shuttle_required: true,
  shuttle_note: "送迎あり"
)

tanaka_service_dates.each do |service_date|
  reservation = billing_tenant.reservations.create!(
    client: tanaka_client,
    service_date: service_date,
    start_time: "08:00",
    end_time: "15:00",
    status: :scheduled,
    notes: "基本報酬 + 入浴介助加算I + 個別機能訓練加算Iロ（送迎あり）"
  )

  billing_tenant.attendances.create!(
    tenant: billing_tenant,
    reservation: reservation,
    status: :present,
    note: "デモ請求実績"
  )
end

InvoiceGenerationService.new(
  tenant: billing_tenant,
  month_start: billing_month_start,
  actor_user: billing_admin,
  mode: "replace"
).call

tanaka_invoice = billing_tenant.invoices.find_by!(
  client_id: tanaka_client.id,
  billing_month: billing_month_start
)

monthly_total_units = Billing::CareServiceUnit.new(tanaka_invoice.invoice_lines.sum(:line_total))
regional_multiplier = Billing::AreaGradeResolver.new.resolve(city_name: billing_tenant.city_name).to_regional_multiplier

# Additional domain-level verification values (limit excess + improvement addition)
limit_split = Billing::BenefitLimitManagementService.new.split_units(
  monthly_total_units: monthly_total_units,
  benefit_limit_units: Billing::CareServiceUnit.new(16_765)
)
improvement_units = Billing::ImprovementAdditionCalculator.new.calculate_units(
  insured_units: limit_split.insured_units,
  rate: "0.245"
)
complex_calculation = Billing::InvoiceCalculationService.new.calculate(
  insured_units: limit_split.insured_units,
  self_pay_units: limit_split.self_pay_units,
  improvement_addition_units: improvement_units,
  regional_multiplier: regional_multiplier,
  copayment_rate: "0.1"
)

puts "[seed] Tanaka case ready (2026-02): tenant=#{billing_tenant.slug}, client=#{tanaka_client.name}"
puts "[seed]  service days=#{tanaka_service_dates.size}, invoice_id=#{tanaka_invoice.id}"
puts "[seed]  monthly_total_units=#{monthly_total_units.value} (expected 17028)"
puts "[seed]  invoice subtotal=#{tanaka_invoice.subtotal_amount}, copayment=#{tanaka_invoice.total_amount}, excess=#{tanaka_invoice.excess_copayment_amount}"
puts "[seed]  domain split insured=#{limit_split.insured_units.value}, self_pay=#{limit_split.self_pay_units.value}, improvement=#{improvement_units.value}"
puts "[seed]  domain final copayment(with limit/improvement)=#{complex_calculation.final_copayment_yen.value}"
