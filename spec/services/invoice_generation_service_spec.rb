require "rails_helper"

RSpec.describe InvoiceGenerationService do
  describe "#call" do
    it "includes additions and persists split/improvement-based breakdown amounts" do
      tenant = Tenant.create!(
        name: "Billing Tenant",
        slug: "billing-tenant-#{SecureRandom.hex(4)}",
        city_name: "目黒区",
        facility_scale: :normal
      )
      admin_role = Role.find_or_create_by!(name: "invoice_generation_service_admin")
      user = tenant.users.create!(
        name: "Billing Admin",
        email: "billing-admin-#{SecureRandom.hex(6)}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        roles: [ admin_role ]
      )
      client = tenant.clients.create!(
        name: "田中 一郎",
        status: :active,
        copayment_rate: 1,
        notes: "要介護1 / 限度額16,765単位 / 1割負担"
      )

      month_start = Date.new(2026, 2, 1)
      month_end = month_start.end_of_month
      service_dates = (month_start..month_end).reject(&:sunday?).first(22)

      tenant.price_items.create!(
        code: "day_service_basic",
        name: "通所介護（7時間以上8時間未満）",
        unit_price: 658,
        billing_unit: :per_use,
        active: true,
        valid_from: Date.new(2026, 1, 1)
      )
      tenant.price_items.create!(
        code: "day_service_bathing_1",
        name: "入浴介助加算I",
        unit_price: 40,
        billing_unit: :per_use,
        active: true,
        valid_from: Date.new(2026, 1, 1)
      )
      tenant.price_items.create!(
        code: "day_service_individual_training_1_ro",
        name: "個別機能訓練加算Iロ",
        unit_price: 76,
        billing_unit: :per_use,
        active: true,
        valid_from: Date.new(2026, 1, 1)
      )

      tenant.contracts.create!(
        client: client,
        start_on: month_start,
        weekdays: [ 1, 2, 3, 4, 5, 6 ],
        services: {
          "bath" => true,
          "rehabilitation" => true
        },
        shuttle_required: true
      )

      service_dates.each do |date|
        reservation = tenant.reservations.create!(
          client: client,
          service_date: date,
          status: :scheduled
        )
        tenant.attendances.create!(
          tenant: tenant,
          reservation: reservation,
          status: :present
        )
      end

      result = described_class.new(
        tenant: tenant,
        month_start: month_start,
        actor_user: user,
        mode: "replace"
      ).call

      expect(result.generated_count).to eq(1)

      invoice = tenant.invoices.find_by!(client_id: client.id, billing_month: month_start)
      expect(invoice.invoice_lines.count).to eq(66)
      expect(invoice.subtotal_amount).to eq(227_504)
      expect(invoice.insurance_claim_amount).to eq(204_753)
      expect(invoice.insured_copayment_amount).to eq(22_751)
      expect(invoice.excess_copayment_amount).to eq(2_866)
      expect(invoice.total_amount).to eq(25_617)
    end
  end
end
