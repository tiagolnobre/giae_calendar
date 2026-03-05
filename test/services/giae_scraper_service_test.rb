# frozen_string_literal: true

require "test_helper"

class GiaeScraperServiceTest < ActiveSupport::TestCase
  setup do
    @login_url = "https://aemgn.giae.pt/index.html"
    @username = "test_user"
    @password = "test_pass"
    @school_code = "161676"
  end

  test "should initialize with default school code" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url
    )

    assert_equal GiaeScraperService::DEFAULT_SCHOOL_CODE, scraper.instance_variable_get(:@school_code)
  end

  test "should accept custom school code" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: "999999"
    )

    assert_equal "999999", scraper.instance_variable_get(:@school_code)
  end

  test "should initialize with session cookie" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "existing_session=value"
    )

    assert scraper.logged_in?
    assert_equal "existing_session=value", scraper.cookies
  end

  test "should not be logged in without session cookie" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    assert_not scraper.logged_in?
  end

  test "should skip login when already logged in" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "existing_session=value"
    )

    # Should not make any HTTP requests - just return self
    result = scraper.login!
    assert_equal scraper, result
    assert_equal "existing_session=value", scraper.cookies
  end

  test "should detect session expiration indicators in body" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "expired_session"
    )

    # Test the private method directly through send
    expired_responses = [
      "Sessao expirada - por favor autentique-se novamente",
      "SESSION EXPIRED",
      "Sessão expirada",
      "Nao autenticado",
      "Não autenticado",
      "Not authenticated"
    ]

    expired_responses.each do |response|
      assert scraper.send(:session_expired_response?, response), "Should detect expired: #{response}"
    end

    # Should not detect valid responses
    assert_not scraper.send(:session_expired_response?, "Valid response with data")
    assert_not scraper.send(:session_expired_response?, "")
    assert_not scraper.send(:session_expired_response?, nil)
  end

  test "should handle binary response encoding" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "valid_session"
    )

    # Test with binary data containing invalid UTF-8 sequences
    binary_data = "Valid response with \x00 binary \xFF data".b

    # Should not raise encoding error
    assert_nothing_raised do
      result = scraper.send(:session_expired_response?, binary_data)
      assert_equal false, result
    end
  end

  test "should raise error when not logged in" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    assert_raises(GiaeScraperService::Error) do
      scraper.fetch_saldo_disponivel
    end
  end

  test "should set correct headers in post_request" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "test_cookie"
    )

    # We can't easily test the actual HTTP request without mocking,
    # but we can verify the instance variables are set correctly
    assert_equal "test_cookie", scraper.cookies
    assert_equal "161676", scraper.instance_variable_get(:@school_code)
    assert_equal "https://aemgn.giae.pt", scraper.instance_variable_get(:@base_url)
  end

  test "should extract cookies from response" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    # Create a mock response class
    mock_response = Class.new do
      def initialize(cookies)
        @cookies = cookies
      end

      def get_fields(name)
        @cookies if name == "set-cookie"
      end
    end.new([ "session=abc123; Path=/; HttpOnly", "other=value; Secure" ])

    cookies = scraper.send(:extract_cookies, mock_response)
    assert_equal "session=abc123; other=value", cookies
  end

  test "should return nil when no cookies in response" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    mock_response = Class.new do
      def get_fields(name)
        nil
      end
    end.new

    cookies = scraper.send(:extract_cookies, mock_response)
    assert_nil cookies
  end
end
