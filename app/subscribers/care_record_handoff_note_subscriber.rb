class CareRecordHandoffNoteSubscriber
  def self.call(payload)
    NotifyFamilyByLineJob.perform_later(payload.deep_symbolize_keys)
  end
end
