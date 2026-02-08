class JsonWebToken
  ALGORITHM = "HS256"

  class << self
    def encode(payload, exp = 24.hours.from_now)
      JWT.encode(payload.merge(exp: exp.to_i), secret_key, ALGORITHM)
    end

    def decode(token)
      body, = JWT.decode(token, secret_key, true, algorithm: ALGORITHM)
      body.with_indifferent_access
    end

    private

    def secret_key
      ENV["JWT_SECRET"].presence ||
        Rails.application.credentials.secret_key_base ||
        Rails.application.secret_key_base
    end
  end
end
