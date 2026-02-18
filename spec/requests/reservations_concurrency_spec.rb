require "rails_helper"
require "timeout"

RSpec.describe "Reservations concurrency", type: :request do
  self.use_transactional_tests = false

  before do
    Reservation.delete_all
    Client.delete_all
    UserRole.delete_all
    RolePermission.delete_all
    User.delete_all
    Role.delete_all
    Permission.delete_all
    Tenant.delete_all
  end

  after do
    Reservation.delete_all
    Client.delete_all
    UserRole.delete_all
    RolePermission.delete_all
    User.delete_all
    Role.delete_all
    Permission.delete_all
    Tenant.delete_all
  end

  let!(:reservations_read) { Permission.find_or_create_by!(key: "reservations:read") }
  let!(:reservations_manage) { Permission.find_or_create_by!(key: "reservations:manage") }

  let!(:manager_role) do
    role = Role.find_or_create_by!(name: "manager_reservations_concurrency")
    role.permissions = [reservations_read, reservations_manage]
    role
  end

  let!(:tenant) { Tenant.create!(name: "Tenant A", slug: "tenant-a-concurrency-#{SecureRandom.hex(4)}", capacity_per_day: 1) }
  let!(:manager_user) do
    tenant.users.create!(
      name: "Manager User",
      email: "manager-concurrency@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [manager_role]
    )
  end
  let!(:client) do
    tenant.clients.create!(
      name: "Concurrency Client",
      status: :active
    )
  end

  it "serializes non-force capacity check per tenant/date" do
    target_date = Date.new(2026, 3, 10)
    date_lock_key = target_date.strftime("%Y%m%d").to_i
    payload = {
      client_id: client.id,
      service_date: target_date.to_s,
      status: "scheduled",
      force: false
    }

    lock_connection = ActiveRecord::Base.connection_pool.checkout
    result_queue = Queue.new

    begin
      lock_connection.transaction do
        lock_connection.execute("SELECT pg_advisory_xact_lock(#{tenant.id}, #{date_lock_key})")

        request_thread = Thread.new do
          session = ActionDispatch::Integration::Session.new(Rails.application)
          session.post "/reservations", params: payload, as: :json, headers: auth_headers_for(manager_user)

          body = JSON.parse(session.response.body) rescue {}
          result_queue << { status: session.response.status, body: body }
        end

        sleep(0.2)
        expect(tenant.reservations.where(service_date: target_date).count).to eq(0)

        tenant.reservations.create!(
          client: client,
          service_date: target_date,
          status: :scheduled
        )

        request_thread.join(0.1)
      end
    ensure
      ActiveRecord::Base.connection_pool.checkin(lock_connection)
    end

    result = Timeout.timeout(5) { result_queue.pop }
    expect(result.fetch(:status)).to eq(422)
    expect(result.dig(:body, "error", "code")).to eq("capacity_exceeded")
    expect(tenant.reservations.where(service_date: target_date).count).to eq(1)
  end
end
