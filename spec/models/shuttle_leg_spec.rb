require "rails_helper"

RSpec.describe ShuttleLeg, type: :model do
  describe "database constraints" do
    it "rejects incompatible direction and status at database level" do
      tenant = Tenant.create!(name: "Tenant Shuttle", slug: "tenant-shuttle-#{SecureRandom.hex(4)}")
      client = tenant.clients.create!(name: "山田 太郎")
      reservation = tenant.reservations.create!(client: client, service_date: Date.new(2026, 2, 27), status: :scheduled)
      operation = tenant.shuttle_operations.create!(reservation: reservation, client: client, service_date: reservation.service_date)

      incompatible = ShuttleLeg.new(
        tenant: tenant,
        shuttle_operation: operation,
        direction: :pickup,
        status: :alighted
      )

      expect { incompatible.save!(validate: false) }.to raise_error(
        ActiveRecord::StatementInvalid,
        /shuttle_legs_direction_status_compatibility/
      )
    end
  end
end
