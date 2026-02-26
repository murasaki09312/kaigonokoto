class FamilyLineInvitationTokenService
  MAX_RETRIES = 2

  def initialize(family_member:, regenerate: false)
    @family_member = family_member
    @regenerate = regenerate
  end

  def call
    retries = 0

    begin
      family_member.with_lock do
        family_member.ensure_line_invitation_token!(regenerate: @regenerate)
      end

      family_member
    rescue ActiveRecord::RecordNotUnique
      retries += 1
      raise if retries > MAX_RETRIES

      family_member.reload
      retry
    end
  end

  private

  attr_reader :family_member
end
