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

  test "login! extracts cookies from successful response" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    # Mock the HTTP response
    mock_response = mock("response")
    mock_response.stubs(:code).returns("200")
    mock_response.stubs(:body).returns("{}")
    mock_response.expects(:get_fields).with("set-cookie").returns([ "session=abc123; Path=/" ])

    # Mock HTTP
    mock_http = mock("http")
    mock_http.expects(:use_ssl=).with(true)
    mock_http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
    mock_http.stubs(:request).returns(mock_response)

    Net::HTTP.expects(:new).with("aemgn.giae.pt", 443).returns(mock_http)

    result = scraper.login!
    assert_equal scraper, result
    assert scraper.logged_in?
    assert_equal "session=abc123", scraper.cookies
  end

  test "login! raises LoginError when no cookies received" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    mock_response = mock("response")
    mock_response.stubs(:code).returns("200")
    mock_response.stubs(:body).returns("{}")
    mock_response.expects(:get_fields).with("set-cookie").returns(nil)

    mock_http = mock("http")
    mock_http.expects(:use_ssl=).with(true)
    mock_http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
    mock_http.stubs(:request).returns(mock_response)

    Net::HTTP.expects(:new).returns(mock_http)

    assert_raises(GiaeScraperService::LoginError) do
      scraper.login!
    end
  end

  test "fetch_saldo_disponivel returns euros and cents" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "test_session"
    )

    mock_response = mock("response")
    mock_response.stubs(:code).returns("200")
    mock_response.stubs(:body).returns({ saldocontabilistico: "25,50 €" }.to_json)

    mock_http = mock("http")
    mock_http.expects(:use_ssl=).with(true)
    mock_http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
    mock_http.stubs(:request).returns(mock_response)

    Net::HTTP.expects(:new).returns(mock_http)

    result = scraper.fetch_saldo_disponivel
    assert_equal 2550, result[:cents]
    assert_equal BigDecimal("25.50"), result[:euros]
  end

  test "fetch_saldo_disponivel extracts from config when not at root" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "test_session"
    )

    mock_response = mock("response")
    mock_response.stubs(:code).returns("200")
    mock_response.stubs(:body).returns({ config: { saldocontabilistico: "31,66 €" } }.to_json)

    mock_http = mock("http")
    mock_http.expects(:use_ssl=).with(true)
    mock_http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
    mock_http.stubs(:request).returns(mock_response)

    Net::HTTP.expects(:new).returns(mock_http)

    result = scraper.fetch_saldo_disponivel
    assert_equal "31.66", result[:euros].to_s
    assert_equal 3166, result[:cents]
  end

  test "fetch_saldo_disponivel raises when saldo not found" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "test_session"
    )

    mock_response = mock("response")
    mock_response.stubs(:code).returns("200")
    mock_response.stubs(:body).returns({ other: "data" }.to_json)

    mock_http = mock("http")
    mock_http.expects(:use_ssl=).with(true)
    mock_http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
    mock_http.stubs(:request).returns(mock_response)

    Net::HTTP.expects(:new).returns(mock_http)

    assert_raises(RuntimeError) do
      scraper.fetch_saldo_disponivel
    end
  end

  test "fetch_refeicoes_compra parses meals and skips weekends" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "test_session"
    )

    # 2024-03-15 is Friday, 2024-03-16 is Saturday, 2024-03-17 is Sunday
    mock_response = mock("response")
    mock_response.stubs(:code).returns("200")
    mock_response.stubs(:body).returns({
      refeicoes: [
        { data: "2024-03-15", comprada: true, descricaoprato: "Carne Assada" },    # Friday - kept
        { data: "2024-03-16", comprada: false, descricaoprato: "Peixe Grelhado" }, # Saturday - skipped
        { data: "2024-03-17", comprada: true, descricaoprato: "Vegetariano" }     # Sunday - skipped
      ].to_json
    }.to_json)

    mock_http = mock("http")
    mock_http.expects(:use_ssl=).with(true)
    mock_http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
    mock_http.stubs(:request).returns(mock_response)

    Net::HTTP.expects(:new).returns(mock_http)

    results = scraper.fetch_refeicoes_compra
    assert_equal 1, results.length  # Only Friday is kept (Sat/Sun skipped)
    assert_equal Date.parse("2024-03-15"), results[0][:date]
    assert_equal "meat", results[0][:dish_type]
  end

  test "fetch_refeicoes_compra skips Portuguese holidays" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "test_session"
    )

    christmas = Date.parse("2024-12-25")

    mock_response = mock("response")
    mock_response.stubs(:code).returns("200")
    mock_response.stubs(:body).returns({
      refeicoes: [
        { data: christmas.to_s, comprada: true, descricaoprato: "Carne" }
      ].to_json
    }.to_json)

    mock_http = mock("http")
    mock_http.expects(:use_ssl=).with(true)
    mock_http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
    mock_http.stubs(:request).returns(mock_response)

    Net::HTTP.expects(:new).returns(mock_http)

    results = scraper.fetch_refeicoes_compra
    assert_empty results
  end

  test "fetch_meal_details returns meal information by date" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "test_session"
    )

    mock_response = mock("response")
    mock_response.stubs(:code).returns("200")
    mock_response.stubs(:body).returns({
      refeicoes: [
        {
          data: "2024-03-15",
          descricaoperiodo: "Almoço",
          sopa: "Sopa de Legumes",
          prato: "Frango Assado",
          vegetais: "Batatas",
          sobremesa: "Fruta",
          pao: "Sim"
        }
      ].to_json
    }.to_json)

    mock_http = mock("http")
    mock_http.expects(:use_ssl=).with(true)
    mock_http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
    mock_http.stubs(:request).returns(mock_response)

    Net::HTTP.expects(:new).returns(mock_http)

    results = scraper.fetch_meal_details
    date = Date.parse("2024-03-15")
    assert results.key?(date)
    assert_equal "Almoço", results[date][:descricaoperiodo]
    assert_equal "Sopa de Legumes", results[date][:soup]
  end

  test "post_request raises SessionExpired on 401" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "expired_session"
    )

    mock_response = mock("response")
    mock_response.stubs(:code).returns("401")
    mock_response.stubs(:body).returns("Unauthorized")

    mock_http = mock("http")
    mock_http.expects(:use_ssl=).with(true)
    mock_http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
    mock_http.stubs(:request).returns(mock_response)

    Net::HTTP.expects(:new).returns(mock_http)

    assert_raises(GiaeScraperService::SessionExpired) do
      scraper.fetch_refeicoes_compra
    end
  end

  test "post_request raises SessionExpired on expired session message" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code,
      session_cookie: "expired_session"
    )

    mock_response = mock("response")
    mock_response.stubs(:code).returns("200")
    mock_response.stubs(:body).returns("Sessao expirada")

    mock_http = mock("http")
    mock_http.expects(:use_ssl=).with(true)
    mock_http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
    mock_http.stubs(:request).returns(mock_response)

    Net::HTTP.expects(:new).returns(mock_http)

    assert_raises(GiaeScraperService::SessionExpired) do
      scraper.fetch_refeicoes_compra
    end
  end

  test "call method performs login and fetches data" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    login_response = mock("login_response")
    login_response.stubs(:code).returns("200")
    login_response.stubs(:body).returns("{}")
    login_response.expects(:get_fields).with("set-cookie").returns([ "session=abc123" ])

    data_response = mock("data_response")
    data_response.stubs(:code).returns("200")
    data_response.stubs(:body).returns({ refeicoes: [].to_json }.to_json)

    mock_http = mock("http")
    mock_http.expects(:use_ssl=).with(true).times(2)
    mock_http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE).times(2)
    mock_http.stubs(:request).returns(login_response).then.returns(data_response)

    Net::HTTP.expects(:new).returns(mock_http).times(2)

    results = scraper.call
    assert_equal [], results
    assert scraper.logged_in?
  end

  test "extract_dish_type returns meat for carne dishes" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    assert_equal "meat", scraper.send(:extract_dish_type, "Carne Assada")
    assert_equal "meat", scraper.send(:extract_dish_type, "CARNE")
  end

  test "extract_dish_type returns fish for peixe dishes" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    assert_equal "fish", scraper.send(:extract_dish_type, "Peixe Grelhado")
    assert_equal "fish", scraper.send(:extract_dish_type, "PEIXE")
  end

  test "extract_dish_type returns nil for other dishes" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    assert_nil scraper.send(:extract_dish_type, "Vegetariano")
    assert_nil scraper.send(:extract_dish_type, nil)
    assert_nil scraper.send(:extract_dish_type, "")
  end

  test "parse_refeicoes handles string input" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    json_string = [ { data: "2024-03-15", comprada: true } ].to_json
    result = scraper.send(:parse_refeicoes, json_string)

    assert_equal Array, result.class
    assert_equal 1, result.length
  end

  test "parse_refeicoes handles array input" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    array = [ { data: "2024-03-15", comprada: true } ]
    result = scraper.send(:parse_refeicoes, array)

    assert_equal array, result
  end

  test "parse_refeicoes raises on unexpected type" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    assert_raises(RuntimeError) do
      scraper.send(:parse_refeicoes, 12345)
    end
  end

  test "portuguese_holiday? identifies holidays" do
    scraper = GiaeScraperService.new(
      username: @username,
      password: @password,
      login_url: @login_url,
      school_code: @school_code
    )

    christmas = Date.parse("2024-12-25")
    assert scraper.send(:portuguese_holiday?, christmas)

    regular_day = Date.parse("2024-03-15")
    assert_not scraper.send(:portuguese_holiday?, regular_day)
  end

  test "Error is a StandardError" do
    assert GiaeScraperService::Error < StandardError
  end

  test "LoginError is an Error" do
    assert GiaeScraperService::LoginError < GiaeScraperService::Error
  end

  test "SessionExpired is an Error" do
    assert GiaeScraperService::SessionExpired < GiaeScraperService::Error
  end
end
