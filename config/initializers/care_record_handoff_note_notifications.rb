ActiveSupport::Notifications.subscribe("care_record.handoff_note_changed") do |_name, _start, _finish, _id, payload|
  CareRecordHandoffNoteSubscriber.call(payload)
end
