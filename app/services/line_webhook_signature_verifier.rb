require "openssl"
require "base64"

class LineWebhookSignatureVerifier
  def initialize(channel_secret: nil)
    @channel_secret = channel_secret.presence ||
      Rails.application.credentials.dig(:line, :channel_secret).presence ||
      ENV["LINE_CHANNEL_SECRET"].to_s
  end

  def valid?(raw_body:, signature:)
    return false if channel_secret.blank?
    return false if signature.to_s.blank?

    expected = Base64.strict_encode64(
      OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), channel_secret, raw_body.to_s)
    )

    secure_compare(expected, signature.to_s)
  end

  private

  attr_reader :channel_secret

  def secure_compare(expected, actual)
    return false unless expected.bytesize == actual.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end
end
