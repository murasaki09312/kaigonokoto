class ApplicationController < ActionController::API
  include Pundit::Authorization

  before_action :authenticate_request

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  private

  def authenticate_request
    Current.reset

    payload = JsonWebToken.decode(bearer_token)
    tenant = Tenant.find(payload.fetch(:tenant_id))
    user = tenant.users.find(payload.fetch(:user_id))

    Current.tenant = tenant
    Current.user = user
  rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound, KeyError, TypeError
    Current.reset
    render_error("unauthorized", "Unauthorized", :unauthorized)
  end

  def bearer_token
    authorization = request.headers["Authorization"].to_s
    return if authorization.blank?

    scheme, token = authorization.split(" ", 2)
    return if scheme != "Bearer" || token.blank?

    token
  end

  def pundit_user
    Current.user
  end

  def current_user
    Current.user
  end

  def current_tenant
    Current.tenant
  end

  def user_response(user)
    {
      id: user.id,
      tenant_id: user.tenant_id,
      name: user.name,
      email: user.email,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  def tenant_response(tenant)
    {
      id: tenant.id,
      name: tenant.name,
      slug: tenant.slug,
      created_at: tenant.created_at,
      updated_at: tenant.updated_at
    }
  end

  def client_response(client)
    {
      id: client.id,
      tenant_id: client.tenant_id,
      name: client.name,
      kana: client.kana,
      birth_date: client.birth_date,
      gender: client.gender,
      phone: client.phone,
      address: client.address,
      emergency_contact_name: client.emergency_contact_name,
      emergency_contact_phone: client.emergency_contact_phone,
      notes: client.notes,
      status: client.status,
      created_at: client.created_at,
      updated_at: client.updated_at
    }
  end

  def render_validation_error(record)
    render_error("validation_error", record.errors.full_messages.to_sentence, :unprocessable_entity)
  end

  def render_forbidden
    render_error("forbidden", "Forbidden", :forbidden)
  end

  def render_not_found
    render_error("not_found", "Not Found", :not_found)
  end

  def render_bad_request(exception)
    render_error("bad_request", exception.message, :bad_request)
  end

  def render_error(code, message, status)
    render json: { error: { code: code, message: message } }, status: status
  end
end
