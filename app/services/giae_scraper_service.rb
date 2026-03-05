# frozen_string_literal: true

require "bigdecimal"
require "net/http"
require "uri"
require "json"

class GiaeScraperService
  class Error < StandardError; end
  class LoginError < Error; end
  class SessionExpired < Error; end

  # Default school code for GIAE
  DEFAULT_SCHOOL_CODE = "161676"

  def initialize(username:, password:, login_url:, school_code: nil, session_cookie: nil)
    @username = username
    @password = password
    @login_url = login_url
    @school_code = school_code || DEFAULT_SCHOOL_CODE
    @base_url = @login_url.sub(/\/[^\/]*\z/, "")
    @cookies = session_cookie  # Use provided session or nil
  end

  def call
    login!
    fetch_refeicoes_compra
  end

  def login!
    # Skip if we already have a session cookie
    return self if logged_in?

    response = perform_login
    @cookies = extract_cookies(response)
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
    url = "#{@base_url}/cgi-bin/webgiae2.exe/loginv2"

    body = {
      modo: "manual",
      escola: @school_code,
      nrcartao: @username,
      codigo: @password,
      urlrecuperacao: @login_url
    }.to_json

    post_request(url, body, skip_auth: true)
  end

  def post_request(url, body, skip_auth: false)
    uri = URI.parse(url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

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

    response = http.request(request)

    Rails.logger.debug "[GiaeScraperService] POST #{url} - Response: #{response.code}"

    # Detect session expiration
    if response.code == "401" || session_expired_response?(response.body)
      raise SessionExpired, "Session has expired (HTTP #{response.code})"
    end

    unless response.code == "200"
      raise("Request failed with status: #{response.code}, body: #{response.body[0..200]}")
    end

    response
  end

  def session_expired_response?(body)
    return false unless body.present?

    # Convert to UTF-8 with error handling for binary responses
    body_utf8 = body.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")

    # Check for common session expiration indicators
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

  def extract_cookies(response)
    cookies = response.get_fields("set-cookie")
    return nil unless cookies

    cookies.map do |cookie|
      cookie.split(";").first.strip
    end.join("; ")
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
