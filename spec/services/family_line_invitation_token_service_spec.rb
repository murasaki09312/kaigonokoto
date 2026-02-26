require "rails_helper"

RSpec.describe FamilyLineInvitationTokenService, type: :service do
  let!(:tenant) { Tenant.create!(name: "Tenant", slug: "tenant-#{SecureRandom.hex(4)}") }
  let!(:client) { tenant.clients.create!(name: "利用者A", status: :active) }

  describe "#call" do
    it "generates invitation token for unlinked family member" do
      family_member = tenant.family_members.create!(
        client: client,
        name: "家族A",
        relationship: "長男",
        line_enabled: false
      )
      family_member.update_columns(line_invitation_token: nil, line_invitation_token_generated_at: nil)

      result = described_class.new(family_member: family_member).call

      expect(result.line_invitation_token).to be_present
      expect(result.line_invitation_token_generated_at).to be_present
    end

    it "keeps existing token when regenerate is false" do
      family_member = tenant.family_members.create!(
        client: client,
        name: "家族B",
        relationship: "長女",
        line_enabled: false
      )
      original_token = family_member.line_invitation_token

      result = described_class.new(family_member: family_member, regenerate: false).call

      expect(result.line_invitation_token).to eq(original_token)
    end

    it "regenerates token when regenerate is true" do
      family_member = tenant.family_members.create!(
        client: client,
        name: "家族C",
        relationship: "次女",
        line_enabled: false
      )
      original_token = family_member.line_invitation_token
      original_generated_at = family_member.line_invitation_token_generated_at

      result = described_class.new(family_member: family_member, regenerate: true).call

      expect(result.line_invitation_token).to be_present
      expect(result.line_invitation_token).not_to eq(original_token)
      expect(result.line_invitation_token_generated_at).to be > original_generated_at
    end

    it "clears token for already linked family member" do
      family_member = tenant.family_members.create!(
        client: client,
        name: "家族D",
        relationship: "配偶者",
        line_user_id: "Ulinked-#{SecureRandom.hex(6)}",
        line_enabled: true
      )

      result = described_class.new(family_member: family_member).call

      expect(result.line_enabled).to eq(true)
      expect(result.line_invitation_token).to be_nil
      expect(result.line_invitation_token_generated_at).to be_nil
    end
  end
end
