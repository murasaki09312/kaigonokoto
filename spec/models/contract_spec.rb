require "rails_helper"

RSpec.describe Contract, type: :model do
  describe "database constraints" do
    it "rejects overlapping periods for same tenant and client" do
      tenant = Tenant.create!(name: "Tenant A", slug: "tenant-a-model")
      client = tenant.clients.create!(name: "山田 太郎")

      Contract.create!(
        tenant: tenant,
        client: client,
        start_on: Date.new(2026, 1, 1),
        end_on: Date.new(2026, 1, 31),
        weekdays: [ 1, 3, 5 ],
        services: { meal: true },
        shuttle_required: false
      )

      overlapping = Contract.new(
        tenant: tenant,
        client: client,
        start_on: Date.new(2026, 1, 15),
        end_on: Date.new(2026, 2, 15),
        weekdays: [ 2, 4 ],
        services: { bath: true },
        shuttle_required: true
      )

      expect { overlapping.save!(validate: false) }.to raise_error(
        ActiveRecord::StatementInvalid,
        /contracts_no_overlapping_periods/
      )
    end
  end
end
