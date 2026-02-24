require "rails_helper"

RSpec.describe InvoiceLine, type: :model do
  describe "database constraints" do
    it "rejects duplicate attendance billing line in same tenant" do
      tenant = Tenant.create!(name: "Tenant InvoiceLine", slug: "tenant-invoice-line-#{SecureRandom.hex(4)}")
      client = tenant.clients.create!(name: "山田 太郎")
      reservation = tenant.reservations.create!(client: client, service_date: Date.new(2026, 2, 1), status: :scheduled)
      attendance = tenant.attendances.create!(reservation: reservation, status: :present)
      invoice = tenant.invoices.create!(client: client, billing_month: Date.new(2026, 2, 1), status: :draft)

      InvoiceLine.create!(
        tenant: tenant,
        invoice: invoice,
        attendance: attendance,
        service_date: reservation.service_date,
        item_name: "通所介護基本利用料",
        quantity: 1.0,
        unit_price: 1200,
        line_total: 1200
      )

      duplicate = InvoiceLine.new(
        tenant: tenant,
        invoice: invoice,
        attendance: attendance,
        service_date: reservation.service_date,
        item_name: "通所介護基本利用料",
        quantity: 1.0,
        unit_price: 1200,
        line_total: 1200
      )

      expect { duplicate.save!(validate: false) }.to raise_error(
        ActiveRecord::StatementInvalid,
        /index_invoice_lines_on_tenant_id_and_attendance_id/
      )
    end
  end
end
