class AuthController < ApplicationController
  skip_before_action :authenticate_request, only: :login

  def login
    tenant = Tenant.find_by(slug: login_params[:tenant_slug])
    user = tenant&.users&.find_by(email: login_params[:email].to_s.downcase)

    if user&.authenticate(login_params[:password])
      Current.tenant = tenant
      Current.user = user

      render json: {
        token: JsonWebToken.encode(tenant_id: tenant.id, user_id: user.id),
        user: user_response(user)
      }, status: :ok
    else
      render_error("unauthorized", "Unauthorized", :unauthorized)
    end
  end

  def me
    render json: {
      user: user_response(current_user),
      permissions: current_user.permissions.distinct.pluck(:key),
      roles: current_user.roles.distinct.pluck(:name)
    }, status: :ok
  end

  def logout
    render json: { success: true }, status: :ok
  end

  private

  def login_params
    params.permit(:tenant_slug, :email, :password)
  end
end
