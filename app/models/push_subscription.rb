# frozen_string_literal: true

class PushSubscription < ApplicationRecord
  belongs_to :user

  encrypts :p256dh, :auth

  validates :endpoint, presence: true, uniqueness: { scope: :user_id }

  def send_push(title:, body:, url: nil)
    data = {
      title: title,
      body: body,
      url: url || "/",
      icon: "/icon.png"
    }

    WebPush.payload_send(
      message: JSON.generate(data),
      endpoint: endpoint,
      p256dh: p256dh,
      auth: auth,
      vapid: {
        subject: "mailto:#{user.email}",
        public_key: Rails.application.credentials.dig(:webpush, :vapid_public_key) || ENV["VAPID_PUBLIC_KEY"],
        private_key: Rails.application.credentials.dig(:webpush, :vapid_private_key) || ENV["VAPID_PRIVATE_KEY"]
      }
    )
  rescue WebPush::ResponseError, WebPush::PushServiceError => e
    Rails.logger.warn "[PushSubscription] Push failed: #{e.message}"
    destroy
    false
  rescue => e
    Rails.logger.error "[PushSubscription] Push failed: #{e.message}"
    false
  end
end
