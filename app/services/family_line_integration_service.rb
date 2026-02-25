class FamilyLineIntegrationService
  Result = Struct.new(:family_member, :error_code, keyword_init: true) do
    def success?
      family_member.present?
    end
  end

  def initialize(invitation_token:, line_user_id:)
    @invitation_token = invitation_token.to_s.strip
    @line_user_id = line_user_id.to_s.strip
  end

  def call
    return failure("invalid_payload") if invitation_token.blank? || line_user_id.blank?

    family_member = FamilyMember.find_by(line_invitation_token: invitation_token)
    return failure("token_not_found") if family_member.blank?

    family_member.with_lock do
      family_member.reload
      return failure("token_not_found") if family_member.line_invitation_token != invitation_token

      family_member.assign_attributes(
        line_user_id: line_user_id,
        line_enabled: true
      )
      family_member.save!
    end

    Result.new(family_member: family_member, error_code: nil)
  rescue ActiveRecord::RecordNotUnique
    failure("line_user_id_taken")
  rescue ActiveRecord::RecordInvalid => error
    error_code = if error.record.errors.attribute_names.include?(:line_user_id)
      "line_user_id_taken"
    else
      "validation_error"
    end
    failure(error_code)
  end

  private

  attr_reader :invitation_token, :line_user_id

  def failure(error_code)
    Result.new(family_member: nil, error_code: error_code)
  end
end
