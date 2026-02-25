require "net/http"
require "uri"
require "json"

class LineMessagingClient
  PUSH_ENDPOINT = URI("https://api.line.me/v2/bot/message/push")

  class Error < StandardError
    attr_reader :error_code, :http_status, :response_body

    def initialize(message, error_code: nil, http_status: nil, response_body: nil)
      super(message)
      @error_code = error_code
      @http_status = http_status
      @response_body = response_body
    end
  end

  def initialize(channel_access_token: nil, endpoint: PUSH_ENDPOINT)
    @channel_access_token = channel_access_token.presence ||
      Rails.application.credentials.dig(:line, :channel_access_token).presence ||
      ENV["LINE_CHANNEL_ACCESS_TOKEN"].to_s
    @endpoint = endpoint
  end

  def push_message(line_user_id:, message:)
    validate_configuration!
    validate_payload!(line_user_id: line_user_id, message: message)

    request = Net::HTTP::Post.new(@endpoint.request_uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{@channel_access_token}"
    request.body = {
      to: line_user_id,
      messages: [ { type: "text", text: message.to_s } ]
    }.to_json

    response = perform_request(request)
    body = parse_json_body(response.body)
    body["request_id"] = response["x-line-request-id"] if response["x-line-request-id"].present?

    return body if response.is_a?(Net::HTTPSuccess)

    raise Error.new(
      body["message"].presence || "LINE API request failed",
      error_code: "line_api_error",
      http_status: response.code.to_i,
      response_body: response.body
    )
  end

  private

  def validate_configuration!
    return if @channel_access_token.present?

    raise Error.new("LINE channel access token is missing", error_code: "line_configuration_missing")
  end

  def validate_payload!(line_user_id:, message:)
    if line_user_id.to_s.strip.blank?
      raise Error.new("LINE user id is missing", error_code: "line_user_id_missing")
    end
    return if message.to_s.strip.present?

    raise Error.new("LINE message text is missing", error_code: "line_message_missing")
  end

  def perform_request(request)
    Net::HTTP.start(@endpoint.host, @endpoint.port, use_ssl: @endpoint.scheme == "https") do |http|
      http.request(request)
    end
  end

  def parse_json_body(raw_body)
    return {} if raw_body.blank?

    JSON.parse(raw_body)
  rescue JSON::ParserError
    {}
  end
end
