# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :user_session, :current_user, :user_signed_in?
  end

  def user_session
    session[:user_id]
  end

  def current_user
    return @current_user if defined?(@current_user)

    # Try to find user from session first
    if session[:user_id].present?
      @current_user = User.find_by(id: session[:user_id])
    end

    # If no session, try to find user from remember cookie
    if @current_user.nil?
      @current_user = user_from_remember_cookie
    end

    @current_user
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    unless user_signed_in?
      redirect_to sign_in_path, alert: "Please sign in to continue."
    end
  end

  def sign_in(user)
    session[:user_id] = user.id
  end

  def sign_out
    # Clear remember cookie if present
    if cookies[:remember_token].present?
      user = User.find_by(remember_token: cookies.signed[:remember_token])
      user&.forget_me!
      cookies.delete(:remember_token)
    end

    session.delete(:user_id)
    @current_user = nil
  end

  def remember_user(user)
    token = user.remember_me!
    cookies.signed[:remember_token] = {
      value: token,
      expires: User::REMEMBER_EXPIRATION,
      httponly: true,
      secure: Rails.env.production?
    }
  end

  private

  def user_from_remember_cookie
    token = cookies.signed[:remember_token]
    return nil if token.blank?

    user = User.find_by(remember_token: token)
    return nil unless user&.remember_token_valid?(token)

    # Restore session from remember cookie
    session[:user_id] = user.id
    user
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
