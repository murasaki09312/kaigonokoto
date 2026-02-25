require "rails_helper"

RSpec.describe FamilyLineIntegrationService, type: :service do
  let!(:tenant) { Tenant.create!(name: "Tenant", slug: "tenant-#{SecureRandom.hex(4)}") }
  let!(:client) { tenant.clients.create!(name: "利用者A", status: :active) }

  describe "#call" do
    it "links family member by invitation token and invalidates token" do
      family_member = tenant.family_members.create!(
        client: client,
        name: "家族A",
        relationship: "長男",
        line_enabled: false
      )

      result = described_class.new(
        invitation_token: family_member.line_invitation_token,
        line_user_id: "Uline-#{SecureRandom.hex(8)}"
      ).call

      expect(result.success?).to eq(true)
      linked_family_member = result.family_member
      expect(linked_family_member.line_enabled).to eq(true)
      expect(linked_family_member.line_user_id).to be_present
      expect(linked_family_member.line_invitation_token).to be_nil
      expect(linked_family_member.line_invitation_token_generated_at).to be_nil
    end

    it "returns token_not_found when token is invalid" do
      result = described_class.new(
        invitation_token: "invalid-token",
        line_user_id: "Uline-#{SecureRandom.hex(8)}"
      ).call

      expect(result.success?).to eq(false)
      expect(result.error_code).to eq("token_not_found")
    end

    it "returns line_user_id_taken when line_user_id is already linked in same tenant" do
      line_user_id = "Uline-#{SecureRandom.hex(8)}"
      tenant.family_members.create!(
        client: client,
        name: "既存家族",
        relationship: "配偶者",
        line_user_id: line_user_id,
        line_enabled: true
      )
      family_member = tenant.family_members.create!(
        client: client,
        name: "新規家族",
        relationship: "長女",
        line_enabled: false
      )

      result = described_class.new(
        invitation_token: family_member.line_invitation_token,
        line_user_id: line_user_id
      ).call

      expect(result.success?).to eq(false)
      expect(result.error_code).to eq("line_user_id_taken")
      expect(family_member.reload.line_enabled).to eq(false)
      expect(family_member.line_user_id).to be_nil
    end
  end
end
