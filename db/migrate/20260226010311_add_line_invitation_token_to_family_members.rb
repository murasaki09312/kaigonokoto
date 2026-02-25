class AddLineInvitationTokenToFamilyMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :family_members, :line_invitation_token, :string
    add_column :family_members, :line_invitation_token_generated_at, :datetime

    add_index :family_members, :line_invitation_token,
      unique: true,
      where: "line_invitation_token IS NOT NULL AND btrim(line_invitation_token) <> ''",
      name: "index_family_members_on_line_invitation_token"
  end
end
