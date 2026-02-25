class FamilyMembersController < ApplicationController
  before_action :set_client
  before_action :set_family_member, only: :line_invitation

  def index
    authorize @client, :show?, policy_class: ClientPolicy

    family_members = @client.family_members.order(primary_contact: :desc, id: :asc)

    render json: {
      family_members: family_members.map { |family_member| family_member_response(family_member) },
      meta: { total: family_members.size }
    }, status: :ok
  end

  def line_invitation
    authorize @client, :update?, policy_class: ClientPolicy

    family_member = FamilyLineInvitationTokenService.new(
      family_member: @family_member,
      regenerate: false
    ).call

    if family_member.linked_to_line?
      render_error("validation_error", "LINE連携済みの家族には連携コードを発行できません。", :unprocessable_entity)
      return
    end

    render json: {
      family_member: family_member_response(family_member),
      line_invitation_token: family_member.line_invitation_token,
      line_invitation_token_generated_at: family_member.line_invitation_token_generated_at
    }, status: :ok
  end

  private

  def set_client
    @client = current_tenant.clients.find(params[:client_id])
  end

  def set_family_member
    @family_member = @client.family_members.find(params[:id])
  end

  def family_member_response(family_member)
    {
      id: family_member.id,
      tenant_id: family_member.tenant_id,
      client_id: family_member.client_id,
      name: family_member.name,
      relationship: family_member.relationship,
      primary_contact: family_member.primary_contact,
      active: family_member.active,
      line_enabled: family_member.line_enabled,
      line_linked: family_member.line_user_id.present?,
      line_invitation_token_generated_at: family_member.line_invitation_token_generated_at,
      created_at: family_member.created_at,
      updated_at: family_member.updated_at
    }
  end
end
