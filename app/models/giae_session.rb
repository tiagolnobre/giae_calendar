# frozen_string_literal: true

class GiaeSession < ApplicationRecord
  belongs_to :user

  # State machine statuses
  # pending: No session, needs login
  # active: Valid session ready to use
  # refreshing: Currently acquiring/refreshing (LOCKED)
  # expired: Session expired, needs refresh
  # failed: Login/refresh failed
  enum :status, {
    pending: 0,
    active: 1,
    refreshing: 2,
    expired: 3,
    failed: 4
  }

  validates :user_id, presence: true
  validates :status, inclusion: { in: statuses.keys }

  # State transition methods with timestamp cleanup

  def transition_to_pending!
    update!(
      status: :pending,
      session_cookie_ciphertext: nil,
      error_message: nil,
      lock_key: nil,
      locked_at: nil,
      locked_by: nil,
      obtained_at: nil,
      expires_at: nil,
      last_used_at: nil,
      refreshed_at: nil
    )
  end

  def transition_to_active!(cookie)
    update!(
      status: :active,
      session_cookie_ciphertext: encrypt(cookie),
      error_message: nil,
      lock_key: nil,
      locked_at: nil,
      locked_by: nil,
      obtained_at: obtained_at || Time.current,
      expires_at: nil,  # No time-based expiration, API-detected only
      last_used_at: Time.current,
      refreshed_at: Time.current
    )
  end

  def transition_to_refreshing!(locked_by:)
    update!(
      status: :refreshing,
      error_message: nil,
      lock_key: SecureRandom.uuid,
      locked_at: Time.current,
      locked_by: locked_by,
      last_used_at: nil
    )
  end

  def transition_to_expired!
    update!(
      status: :expired,
      session_cookie_ciphertext: nil,
      lock_key: nil,
      locked_at: nil,
      locked_by: nil,
      expires_at: nil
      # Keep: obtained_at, last_used_at for audit
    )
  end

  def transition_to_failed!(message)
    update!(
      status: :failed,
      error_message: message,
      lock_key: nil,
      locked_at: nil,
      locked_by: nil,
      obtained_at: nil,
      expires_at: nil
      # Keep: refreshed_at to know when attempt was made
    )
  end

  def decrypt_cookie
    return nil unless session_cookie_ciphertext.present?

    encryptor.decrypt_and_verify(session_cookie_ciphertext)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  private

  def encrypt(data)
    encryptor.encrypt_and_sign(data)
  end

  def encryptor
    @encryptor ||= ActiveSupport::MessageEncryptor.new(
      Rails.application.credentials.secret_key_base[0..31],
      cipher: "aes-256-gcm",
      serializer: JSON
    )
  end
end
