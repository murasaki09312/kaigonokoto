module RequestHelpers
  def json_body
    JSON.parse(response.body)
  end

  def auth_headers_for(user)
    {
      "Authorization" => "Bearer #{JsonWebToken.encode(tenant_id: user.tenant_id, user_id: user.id)}",
      "Content-Type" => "application/json"
    }
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
