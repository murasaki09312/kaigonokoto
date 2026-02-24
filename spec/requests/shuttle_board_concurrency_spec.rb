require "rails_helper"

RSpec.describe "ShuttleBoard concurrency", type: :request do
  self.use_transactional_tests = false

  let!(:shuttles_read) { Permission.find_or_create_by!(key: "shuttles:read") }
  let!(:shuttles_manage) { Permission.find_or_create_by!(key: "shuttles:manage") }

  let!(:manager_role) do
    role = Role.find_or_create_by!(name: "manager_shuttle_concurrency_spec")
    role.permissions = [ shuttles_read, shuttles_manage ]
    role
  end

  let!(:tenant) { Tenant.create!(name: "Tenant Shuttle Concurrency", slug: "tenant-shuttle-concurrency-#{SecureRandom.hex(4)}") }

  let!(:manager_user) do
    tenant.users.create!(
      name: "Shuttle Manager",
      email: "shuttle-manager-concurrency-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ manager_role ]
    )
  end

  let!(:client) do
    tenant.clients.create!(
      name: "同時実行 送迎利用者",
      kana: "ドウジジッコウ ソウゲイリヨウシャ",
      status: :active
    )
  end

  let!(:reservation) do
    tenant.reservations.create!(
      client: client,
      service_date: Date.new(2026, 2, 27),
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled
    )
  end

  describe "concurrent shuttle leg upsert" do
    it "does not create duplicate operation/legs and does not return 500 for first concurrent writes" do
      path = "/api/v1/reservations/#{reservation.id}/shuttle_legs/pickup"
      ready = Queue.new
      barrier = Queue.new

      threaded_result = spawn_put_thread(
        reservation_id: reservation.id,
        direction: "pickup",
        path: path,
        params: {
          status: "boarded",
          note: "threaded update"
        },
        headers: auth_headers_for(manager_user),
        ready: ready,
        barrier: barrier
      )

      ready.pop
      barrier << true

      put path, params: {
        status: "cancelled",
        note: "main update"
      }, as: :json, headers: auth_headers_for(manager_user)

      first_result = threaded_result.value
      second_result = { status: response.status, body: json_body }
      results = [ first_result, second_result ]

      expect(results.map { |result| result.fetch(:status) }).not_to include(500)
      expect(results.map { |result| result.fetch(:status) }).to all(satisfy { |status| [ 200, 422 ].include?(status) })

      results.select { |result| result.fetch(:status) == 422 }.each do |result|
        expect(result.fetch(:body).dig("error", "code")).to eq("validation_error")
      end

      expect(tenant.shuttle_operations.where(reservation_id: reservation.id).count).to eq(1)

      operation = tenant.shuttle_operations.find_by!(reservation_id: reservation.id)
      expect(tenant.shuttle_legs.where(shuttle_operation_id: operation.id, direction: :pickup).count).to eq(1)

      final_leg = tenant.shuttle_legs.find_by!(shuttle_operation_id: operation.id, direction: :pickup)
      expect(final_leg.status).to be_in(%w[boarded cancelled])
    end
  end

  private

  def spawn_put_thread(reservation_id:, direction:, path:, params:, headers:, ready:, barrier:)
    Thread.new do
      ready << true
      barrier.pop
      status = nil
      response_body = nil

      Rails.application.executor.wrap do
        env = Rack::MockRequest.env_for(
          path,
          method: "PUT",
          "CONTENT_TYPE" => "application/json",
          "HTTP_AUTHORIZATION" => headers.fetch("Authorization"),
          input: params.to_json
        )
        env["action_dispatch.request.path_parameters"] = {
          controller: Api::V1::ShuttleLegsController.controller_path,
          action: "upsert",
          reservation_id: reservation_id.to_s,
          direction: direction
        }

        app = Api::V1::ShuttleLegsController.action(:upsert)
        status, _response_headers, rack_body = app.call(env)
        response_body = +""
        rack_body.each { |chunk| response_body << chunk }
        rack_body.close if rack_body.respond_to?(:close)
      end

      {
        status: status,
        body: JSON.parse(response_body)
      }
    end
  end
end
