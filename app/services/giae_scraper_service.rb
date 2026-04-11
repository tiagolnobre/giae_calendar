# frozen_string_literal: true

require "bigdecimal"
require "net/http"
require "uri"
require "json"

class GiaeScraperService
  class Error < StandardError; end
  class LoginError < Error; end
  class SessionExpired < Error; end
  class AccessDenied < Error; end

  # Default school code for GIAE
  DEFAULT_SCHOOL_CODE = "161676"

  def initialize(username:, password:, login_url:, school_code: nil, session_cookie: nil)
    @username = username
    @password = password
    @login_url = login_url
    @school_code = school_code || DEFAULT_SCHOOL_CODE
    @base_url = @login_url.sub(/\/[^\/]*\z/, "")
    @cookies = session_cookie  # Use provided session or nil

    GiaeDebug.log("GiaeScraperService initialized", {
      username: @username,
      school_code: @school_code,
      base_url: @base_url,
      login_url: @login_url,
      has_initial_cookies: @cookies.present?
    })
  end

  def call
    login!
    fetch_refeicoes_compra
  end

  def login!
    GiaeDebug.log("login! called", { already_logged_in: logged_in?, has_cookies: @cookies.present? })

    # Skip if we already have a session cookie
    if logged_in?
      GiaeDebug.log("Already logged in, skipping login")
      return self
    end

    response = perform_login
    GiaeDebug.log("Login response received", { status: response.code })

    @cookies = extract_cookies(response)
    GiaeDebug.log("Cookies extracted", { cookies: @cookies })

    raise(LoginError, "Login failed - no session cookie received") unless @cookies
    self
  end

  def logged_in?
    @cookies.present?
  end

  def fetch_saldo_disponivel
    url = "#{@base_url}/cgi-bin/webgiae2.exe/refeicoes"
    body = { idsetorconta: 0, acao: "get_refeicoes_compra" }.to_json

    response = post_request(url, body)
    data = JSON.parse(response.body)

    raw = data.dig("saldocontabilistico") ||
      data.dig("config", "saldocontabilistico") ||
      raise("saldocontabilistico not found in response: #{data.inspect}")

    normalized = raw.to_s.gsub(/[^\d,]/, "").tr(",", ".")
    euros = BigDecimal(normalized)
    cents = (euros * 100).to_i

    { euros: euros, cents: cents }
  end

  def fetch_refeicoes_compra
    url = "#{@base_url}/cgi-bin/webgiae2.exe/refeicoes"
    body = { idsetorconta: 0, acao: "get_refeicoes_compra" }.to_json

    response = post_request(url, body)
    data = JSON.parse(response.body)

    refeicoes = parse_refeicoes(data["refeicoes"])
    results = []

    refeicoes.each do |ref|
      date = Date.parse(ref["data"])
      next if date.saturday? || date.sunday?
      next if portuguese_holiday?(date)

      bought = ref["comprada"] == true || ref["comprada"] == "true"
      dish_type = extract_dish_type(ref["descricaoprato"])

      results << { date: date, bought: bought, dish_type: dish_type }
    end

    results
  end

  def fetch_meal_details
    url = "#{@base_url}/cgi-bin/webgiae2.exe/refeicoes"
    body = { acao: "get_ementas" }.to_json

    response = post_request(url, body)
    data = JSON.parse(response.body)

    refeicoes = parse_refeicoes(data["refeicoes"])

    refeicoes.each_with_object({}) do |ref, acc|
      date = Date.parse(ref["data"])

      acc[date] = {
        descricaoperiodo: ref["descricaoperiodo"],
        soup: ref["sopa"],
        main_dish: ref["prato"],
        vegetables: ref["vegetais"],
        dessert: ref["sobremesa"],
        bread: ref["pao"]
      }
    end
  end

  attr_reader :cookies

  private

  def perform_login
    GiaeDebug.log("Starting login")

    url = "#{@base_url}/cgi-bin/webgiae2.exe/loginv2"

    body = {
      modo: "manual",
      escola: @school_code,
      nrcartao: @username,
      codigo: @password,
      urlrecuperacao: @login_url
    }.to_json

    GiaeDebug.log("Login body", body)

    response = post_request(url, body, skip_auth: true)

    GiaeDebug.log("Login response received", { status: response.code })

    response
  end

  def post_request(url, body, skip_auth: false)
    uri = URI.parse(url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    # SECURITY NOTE: SSL verification is disabled to accommodate GIAE servers
    # with self-signed or problematic certificates. This is a known security
    # trade-off. To enable verification in production, remove the line below
    # or set to OpenSSL::SSL::VERIFY_PEER
    # Brakeman: ignore SSL verification bypass - intentional for GIAE compatibility
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.open_timeout = 45
    http.read_timeout = 45

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json, text/javascript, */*; q=0.01"
    request["Origin"] = @base_url
    request["Referer"] = @login_url
    request["X-Requested-With"] = "XMLHttpRequest"

    unless skip_auth
      raise(Error, "Not logged in. Call login! first.") unless @cookies
      request["Cookie"] = @cookies
    end

    request.body = body

    # Debug logging
    headers = {
      "Content-Type" => request["Content-Type"],
      "Accept" => request["Accept"],
      "Origin" => request["Origin"],
      "Referer" => request["Referer"],
      "X-Requested-With" => request["X-Requested-With"]
    }
    headers["Cookie"] = request["Cookie"] if request["Cookie"]

    GiaeDebug.log_request("POST", "POST", url, headers, body, request["Cookie"])

    response = http.request(request)

    GiaeDebug.log_response("POST", response)

    Rails.logger.debug "[GiaeScraperService] POST #{url} - Response: #{response.code}"

    # Detect session expiration
    if response.code == "401" || session_expired_response?(response.body)
      raise SessionExpired, "Session has expired (HTTP #{response.code})"
    end

    # Detect access denied
    if response.code == "403" || access_denied_response?(response.body)
      raise AccessDenied, "Access denied (HTTP #{response.code})"
    end

    unless response.code == "200"
      raise("Request failed with status: #{response.code}, body: #{response.body[0..200]}")
    end

    response
  end

  def session_expired_response?(body)
    return false unless body.present?

    body_utf8 = body.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")

    indicators = [
      "sessao expirada",
      "session expired",
      "sessão expirada",
      "nao autenticado",
      "não autenticado",
      "not authenticated"
    ]

    indicators.any? { |indicator| body_utf8.downcase.include?(indicator) }
  end

  def access_denied_response?(body)
    return false unless body.present?

    body_utf8 = body.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")

    indicators = [
      "access denied",
      "acesso negado",
      "proibido",
      "forbidden",
      "unauthorized"
    ]

    indicators.any? { |indicator| body_utf8.downcase.include?(indicator) }
  end

  def extract_cookies(response)
    cookies = response.get_fields("set-cookie")

    GiaeDebug.log("extract_cookies called", {
      has_set_cookie: cookies.present?,
      set_cookie_count: cookies&.length
    })

    return nil unless cookies

    GiaeDebug.log("Raw cookies from response", cookies)

    parsed_cookies = cookies.map do |cookie|
      parsed = cookie.split(";").first.strip
      GiaeDebug.log("Parsed cookie", { original: cookie[0..50], parsed: parsed })
      parsed
    end.join("; ")

    GiaeDebug.log("Final parsed cookies", parsed_cookies)

    parsed_cookies
  end

  def parse_refeicoes(refeicoes_raw)
    case refeicoes_raw
    when String
      JSON.parse(refeicoes_raw)
    when Array
      refeicoes_raw
    else
      raise "Unexpected refeicoes type: #{refeicoes_raw.class}"
    end
  end

  def extract_dish_type(descricaoprato)
    return nil if descricaoprato.blank?

    descricaoprato_down = descricaoprato.downcase
    if descricaoprato_down.include?("carne")
      "meat"
    elsif descricaoprato_down.include?("peixe")
      "fish"
    end
  end

  def portuguese_holiday?(date)
    Holidays.on(date, :pt).any?
  end
end
