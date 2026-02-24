require "rails_helper"

RSpec.describe "Reservations concurrency", type: :request do
  let!(:reservations_read) { Permission.find_or_create_by!(key: "reservations:read") }
  let!(:reservations_manage) { Permission.find_or_create_by!(key: "reservations:manage") }

  let!(:manager_role) do
    role = Role.find_or_create_by!(name: "manager_reservations_concurrency_spec")
    role.permissions = [ reservations_read, reservations_manage ]
    role
  end

  let!(:tenant) { Tenant.create!(name: "Tenant Concurrency", slug: "tenant-concurrency-#{SecureRandom.hex(4)}", capacity_per_day: 1) }

  let!(:manager_user) do
    tenant.users.create!(
      name: "Manager User",
      email: "manager-concurrency-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ manager_role ]
    )
  end

  let!(:contract_client_a) do
    tenant.clients.create!(
      name: "契約 利用者A",
      kana: "ケイヤク リヨウシャエー",
      status: :active
    )
  end

  let!(:contract_client_b) do
    tenant.clients.create!(
      name: "契約 利用者B",
      kana: "ケイヤク リヨウシャビー",
      status: :active
    )
  end

  let!(:manual_client) do
    tenant.clients.create!(
      name: "手動 利用者",
      kana: "シュドウ リヨウシャ",
      status: :active
    )
  end

  let(:target_date) { Date.new(2026, 3, 9) }

  before do
    tenant.contracts.create!(
      client: contract_client_a,
      start_on: Date.new(2026, 3, 1),
      end_on: nil,
      weekdays: [ 1 ],
      services: { "meal" => true },
      shuttle_required: false
    )

    tenant.contracts.create!(
      client: contract_client_b,
      start_on: Date.new(2026, 3, 1),
      end_on: nil,
      weekdays: [ 1 ],
      services: { "meal" => true },
      shuttle_required: false
    )
  end

  describe "POST /api/v1/reservations/generate" do
    it "does not exceed capacity when generate runs concurrently" do
      generate_payload = {
        start_on: target_date.to_s,
        end_on: target_date.to_s,
        start_time: "09:30",
        end_time: "16:00"
      }

      ready = Queue.new
      barrier = Queue.new
      threaded_result = spawn_post_thread(
        "/api/v1/reservations/generate",
        generate_payload,
        auth_headers_for(manager_user),
        ready: ready,
        barrier: barrier
      )

      ready.pop
      barrier << true
      post "/api/v1/reservations/generate", params: generate_payload, as: :json, headers: auth_headers_for(manager_user)
      main_result = { status: response.status, body: json_body }
      first_result = threaded_result.value
      second_result = main_result

      expect(first_result.fetch(:status)).to eq(201)
      expect(second_result.fetch(:status)).to eq(201)

      scheduled_count = tenant.reservations.scheduled_on(target_date).count
      expect(scheduled_count).to eq(1)

      skipped_dates = [ first_result, second_result ].flat_map do |result|
        result.fetch(:body).dig("meta", "capacity_skipped_dates") || []
      end
      expect(skipped_dates).to include(target_date.to_s)
    end

    it "does not exceed capacity when create and generate run concurrently" do
      generate_payload = {
        start_on: target_date.to_s,
        end_on: target_date.to_s,
        start_time: "09:30",
        end_time: "16:00"
      }
      create_payload = {
        client_id: manual_client.id,
        service_date: target_date.to_s,
        start_time: "09:00",
        end_time: "15:00"
      }

      ready = Queue.new
      barrier = Queue.new
      threaded_result = spawn_post_thread(
        "/api/v1/reservations/generate",
        generate_payload,
        auth_headers_for(manager_user),
        ready: ready,
        barrier: barrier
      )
      ready.pop
      barrier << true
      post "/reservations", params: create_payload, as: :json, headers: auth_headers_for(manager_user)
      create_result = { status: response.status, body: json_body }
      generate_result = threaded_result.value

      expect(generate_result.fetch(:status)).to eq(201)
      expect([ 201, 422 ]).to include(create_result.fetch(:status))

      if create_result.fetch(:status) == 422
        expect(create_result.fetch(:body).dig("error", "code")).to eq("capacity_exceeded")
      else
        expect(generate_result.fetch(:body).dig("meta", "capacity_skipped_dates") || []).to include(target_date.to_s)
      end

      scheduled_count = tenant.reservations.scheduled_on(target_date).count
      expect(scheduled_count).to eq(1)
    end
  end

  private

  def spawn_post_thread(path, params, headers, ready:, barrier:)
    Thread.new do
      ready << true
      barrier.pop
      status = nil
      response_body = nil
      Rails.application.executor.wrap do
        env = Rack::MockRequest.env_for(
          path,
          method: "POST",
          "CONTENT_TYPE" => "application/json",
          "HTTP_AUTHORIZATION" => headers.fetch("Authorization"),
          input: params.to_json
        )
        app = ReservationsController.action(:generate)
        status, _response_headers, rack_body = app.call(env)
        response_body = +""
        rack_body.each { |chunk| response_body << chunk }
        rack_body.close if rack_body.respond_to?(:close)
      end
      parsed_body = JSON.parse(response_body)

      {
        status: status,
        body: parsed_body
      }
    end
  end
end
