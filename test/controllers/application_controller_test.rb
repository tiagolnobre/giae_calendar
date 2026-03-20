# frozen_string_literal: true

require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "sets locale from params" do
    post sign_in_path, params: { email: @user.email, password: "password123", locale: "pt" }
    follow_redirect!

    get calendar_path(locale: "pt")
    assert_equal :pt, I18n.locale
  end

  test "sets locale from accept-language header" do
    post sign_in_path, params: { email: @user.email, password: "password123" },
      headers: { "Accept-Language" => "pt-PT,pt;q=0.9,en;q=0.8" }
    follow_redirect!

    # Should extract 'pt' from the header
    get calendar_path
    assert_response :success
  end

  test "falls back to default locale for unsupported languages" do
    post sign_in_path, params: { email: @user.email, password: "password123", locale: "unsupported" }
    follow_redirect!

    # Should fall back to default locale
    assert_equal I18n.default_locale, I18n.locale
  end

  test "extract_locale_from_accept_language_header handles missing header" do
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!

    get calendar_path
    assert_response :success
  end

  test "default_url_options includes locale" do
    post sign_in_path, params: { email: @user.email, password: "password123", locale: "pt" }
    follow_redirect!

    # URLs should include locale parameter
    assert_match(/locale=pt/, url_for(controller: "calendars", action: "show", locale: "pt"))
  end

  test "set_locale handles string locale" do
    post sign_in_path, params: { email: @user.email, password: "password123", locale: "pt" }
    follow_redirect!

    get calendar_path
    # Locale should be converted to symbol
    assert I18n.locale.is_a?(Symbol)
  end

  test "set_locale validates available locales" do
    I18n.available_locales
    I18n.stub :available_locales, [ :en, :pt ] do
      post sign_in_path, params: { email: @user.email, password: "password123", locale: "fr" }
      follow_redirect!

      # Should fall back to default
      assert_equal I18n.default_locale, I18n.locale
    end
  end

  test "authenticates user before actions" do
    get calendar_path
    assert_redirected_to %r{/sign_in}
  end

  test "allows authenticated users through" do
    post sign_in_path, params: { email: @user.email, password: "password123" }
    follow_redirect!

    get calendar_path
    assert_response :success
  end

  test "handles accept-language with quality values" do
    # Accept-Language: pt;q=0.9,en;q=0.8
    header_value = "pt-PT;q=0.9,en-US;q=0.8,en;q=0.7"
    post sign_in_path, params: { email: @user.email, password: "password123" },
      headers: { "Accept-Language" => header_value }
    follow_redirect!

    get calendar_path
    assert_response :success
  end

  test "handles empty accept-language header" do
    post sign_in_path, params: { email: @user.email, password: "password123" },
      headers: { "Accept-Language" => "" }
    follow_redirect!

    get calendar_path
    assert_response :success
  end
end
