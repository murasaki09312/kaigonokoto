module Api
  module Webhooks
    class LineController < ActionController::API
      def create
        raw_body = request.raw_post.to_s
        signature = request.headers["X-Line-Signature"].to_s

        verifier = LineWebhookSignatureVerifier.new
        return head :unauthorized unless verifier.valid?(raw_body: raw_body, signature: signature)

        payload = JSON.parse(raw_body)
        events = Array(payload["events"])
        events.each { |event| process_message_event(event) }

        head :ok
      rescue JSON::ParserError
        render json: { error: { code: "bad_request", message: "Invalid JSON payload" } }, status: :bad_request
      end

      private

      def process_message_event(event)
        return unless event["type"] == "message"

        message = event["message"]
        return unless message.is_a?(Hash) && message["type"] == "text"

        invitation_token = extract_invitation_token(message["text"])
        return if invitation_token.blank?

        line_user_id = event.dig("source", "userId").to_s.strip
        return if line_user_id.blank?

        result = FamilyLineIntegrationService.new(
          invitation_token: invitation_token,
          line_user_id: line_user_id
        ).call

        send_result_message(result: result, line_user_id: line_user_id)
      rescue StandardError => error
        Rails.logger.error("[Api::Webhooks::LineController] failed to process event error=#{error.class}: #{error.message}")
      end

      def send_result_message(result:, line_user_id:)
        line_client = LineMessagingClient.new

        if result.success?
          family_member = result.family_member
          message = "#{family_member.client.name}さんのご家族として連携が完了しました！"
          line_client.push_message(line_user_id: line_user_id, message: message)
        else
          message = if result.error_code == "token_expired"
            "連携コードの有効期限が切れています。施設スタッフにQRコードの再発行をご依頼ください。"
          else
            "連携コードを確認してください。問題が続く場合は施設スタッフへお問い合わせください。"
          end
          line_client.push_message(line_user_id: line_user_id, message: message)
        end
      rescue StandardError => error
        Rails.logger.error("[Api::Webhooks::LineController] failed to send result message error=#{error.class}: #{error.message}")
      end

      def extract_invitation_token(raw_text)
        normalized_text = raw_text.to_s.tr("：", ":").strip
        matched = normalized_text.match(/\A連携コード:\s*(?<token>[A-Za-z0-9\-_]+=*)\z/)
        matched&.[](:token).to_s.strip.presence
      end
    end
  end
end
