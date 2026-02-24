require "rails_helper"

RSpec.describe "TodayBoard concurrency", type: :request do
  self.use_transactional_tests = false

  let!(:today_board_read) { Permission.find_or_create_by!(key: "today_board:read") }
  let!(:attendances_manage) { Permission.find_or_create_by!(key: "attendances:manage") }
  let!(:care_records_manage) { Permission.find_or_create_by!(key: "care_records:manage") }

  let!(:board_manager_role) do
    role = Role.find_or_create_by!(name: "board_manager_today_board_concurrency_spec")
    role.permissions = [ today_board_read, attendances_manage, care_records_manage ]
    role
  end

  let!(:tenant) { Tenant.create!(name: "Tenant Concurrency", slug: "tenant-board-#{SecureRandom.hex(4)}") }

  let!(:board_manager_user) do
    tenant.users.create!(
      name: "Board Manager",
      email: "board-manager-concurrency-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      roles: [ board_manager_role ]
    )
  end

  let!(:client) do
    tenant.clients.create!(
      name: "同時実行 利用者",
      kana: "ドウジジッコウ リヨウシャ",
      status: :active
    )
  end

  let!(:reservation) do
    tenant.reservations.create!(
      client: client,
      service_date: Date.new(2026, 2, 24),
      start_time: "09:30",
      end_time: "16:00",
      status: :scheduled
    )
  end

  describe "concurrent upsert" do
    it "keeps attendance upsert stable for first concurrent writes" do
      path = "/api/v1/reservations/#{reservation.id}/attendance"
      ready = Queue.new
      barrier = Queue.new
      threaded_result = spawn_put_thread(
        controller: Api::V1::AttendancesController,
        action: :upsert,
        reservation_id: reservation.id,
        path: path,
        params: {
          status: "present",
          note: "threaded save"
        },
        headers: auth_headers_for(board_manager_user),
        ready: ready,
        barrier: barrier
      )

      ready.pop
      barrier << true

      put path, params: {
        status: "absent",
        absence_reason: "同日体調不良"
      }, as: :json, headers: auth_headers_for(board_manager_user)

      main_result = { status: response.status, body: json_body }
      first_result = threaded_result.value

      expect(first_result.fetch(:status)).to eq(200)
      expect(main_result.fetch(:status)).to eq(200)
      expect(tenant.attendances.where(reservation_id: reservation.id).count).to eq(1)
      expect(tenant.attendances.find_by!(reservation_id: reservation.id).status).to be_in(%w[present absent])
    end

    it "keeps care_record upsert stable for first concurrent writes" do
      path = "/api/v1/reservations/#{reservation.id}/care_record"
      ready = Queue.new
      barrier = Queue.new
      threaded_result = spawn_put_thread(
        controller: Api::V1::CareRecordsController,
        action: :upsert,
        reservation_id: reservation.id,
        path: path,
        params: {
          body_temperature: 36.5,
          care_note: "threaded note"
        },
        headers: auth_headers_for(board_manager_user),
        ready: ready,
        barrier: barrier
      )

      ready.pop
      barrier << true

      put path, params: {
        body_temperature: 36.7,
        handoff_note: "main note"
      }, as: :json, headers: auth_headers_for(board_manager_user)

      main_result = { status: response.status, body: json_body }
      first_result = threaded_result.value

      expect(first_result.fetch(:status)).to eq(200)
      expect(main_result.fetch(:status)).to eq(200)
      expect(tenant.care_records.where(reservation_id: reservation.id).count).to eq(1)
      expect(tenant.care_records.find_by!(reservation_id: reservation.id).body_temperature.to_s).to be_in([ "36.5", "36.7" ])
    end
  end

  private

  def spawn_put_thread(controller:, action:, reservation_id:, path:, params:, headers:, ready:, barrier:)
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
          controller: controller.controller_path,
          action: action.to_s,
          reservation_id: reservation_id.to_s
        }

        app = controller.action(action)
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
