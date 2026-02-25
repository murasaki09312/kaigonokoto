require "rails_helper"

RSpec.describe CareRecordHandoffNoteSubscriber, type: :model do
  include ActiveJob::TestHelper

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    example.run
  ensure
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end

  it "enqueues NotifyFamilyByLineJob when event is instrumented" do
    payload = {
      event_id: SecureRandom.uuid,
      tenant_id: 1,
      client_id: 2,
      reservation_id: 3,
      care_record_id: 4,
      actor_user_id: 5,
      handoff_note: "申し送り",
      occurred_at: Time.current.iso8601
    }

    expect do
      ActiveSupport::Notifications.instrument(CareRecordHandoffEventPublisher::EVENT_NAME, payload)
    end.to have_enqueued_job(NotifyFamilyByLineJob)
  end
end
