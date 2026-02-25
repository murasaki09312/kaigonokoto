require "rails_helper"
require "openssl"
require "base64"

RSpec.describe "LINE Webhooks", type: :request do
  let(:channel_secret) { "line-webhook-secret-#{SecureRandom.hex(8)}" }
  let!(:tenant) { Tenant.create!(name: "Tenant A", slug: "line-webhook-a-#{SecureRandom.hex(4)}") }
  let!(:client) { tenant.clients.create!(name: "利用者A", status: :active) }
  let!(:family_member) do
    tenant.family_members.create!(
      client: client,
      name: "家族A",
      relationship: "長男",
      line_enabled: false
    )
  end
  let(:line_user_id) { "Ulinewebhook#{SecureRandom.hex(6)}" }
  let(:line_client) { instance_double(LineMessagingClient, push_message: {}) }

  before do
    allow(LineMessagingClient).to receive(:new).and_return(line_client)
    allow(Rails.application.credentials).to receive(:dig).with(:line, :channel_secret).and_return(channel_secret)
    allow(Rails.application.credentials).to receive(:dig).with(:line, :channel_access_token).and_call_original
  end

  def signature_for(raw_body)
    Base64.strict_encode64(
      OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), channel_secret, raw_body)
    )
  end

  def build_payload(text:)
    {
      destination: "Udestination",
      events: [
        {
          type: "message",
          mode: "active",
          timestamp: Time.current.to_i * 1000,
          source: { type: "user", userId: line_user_id },
          replyToken: "reply-token",
          message: { id: "message-id", type: "text", text: text }
        }
      ]
    }
  end

  it "links family member and sends completion message when signature and token are valid" do
    payload = build_payload(text: "連携コード:#{family_member.line_invitation_token}")
    raw_body = payload.to_json

    post "/api/webhooks/line",
      params: raw_body,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Line-Signature" => signature_for(raw_body)
      }

    expect(response).to have_http_status(:ok)

    linked = family_member.reload
    expect(linked.line_enabled).to eq(true)
    expect(linked.line_user_id).to eq(line_user_id)
    expect(linked.line_invitation_token).to be_nil

    expect(line_client).to have_received(:push_message).with(
      line_user_id: line_user_id,
      message: include("連携が完了")
    )
  end

  it "returns 401 when signature is invalid" do
    payload = build_payload(text: "連携コード:#{family_member.line_invitation_token}")
    raw_body = payload.to_json

    post "/api/webhooks/line",
      params: raw_body,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Line-Signature" => "invalid-signature"
      }

    expect(response).to have_http_status(:unauthorized)
    expect(family_member.reload.line_enabled).to eq(false)
    expect(line_client).not_to have_received(:push_message)
  end

  it "keeps family member unlinked and sends failure message when token is unknown" do
    payload = build_payload(text: "連携コード:unknown-token")
    raw_body = payload.to_json

    post "/api/webhooks/line",
      params: raw_body,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Line-Signature" => signature_for(raw_body)
      }

    expect(response).to have_http_status(:ok)
    expect(family_member.reload.line_enabled).to eq(false)

    expect(line_client).to have_received(:push_message).with(
      line_user_id: line_user_id,
      message: include("連携コードを確認")
    )
  end
end
