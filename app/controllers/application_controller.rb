# frozen_string_literal: true

class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  include Authentication

  before_action :set_locale
  before_action :authenticate_user!

  def set_locale
    locale = params[:locale] || extract_locale_from_accept_language_header || I18n.default_locale
    I18n.locale = I18n.available_locales.include?(locale.to_sym) ? locale.to_sym : I18n.default_locale
  end

  def extract_locale_from_accept_language_header
    return nil unless request.headers["Accept-Language"]

    request.headers["Accept-Language"]
      .split(",")
      .first
      &.strip
      &.split("-")
      &.first
      &.to_sym
  end

  def default_url_options
    { locale: I18n.locale }
  end
end
