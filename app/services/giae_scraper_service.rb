# frozen_string_literal: true

require "bigdecimal"

class GiaeScraperService
  class Error < StandardError; end
  class LoginError < Error; end
  class NavigationError < Error; end
  class CalendarParseError < Error; end

  MONTH_MAP = {
    "Janeiro" => 1, "Fevereiro" => 2, "Março" => 3, "Abril" => 4,
    "Maio" => 5, "Junho" => 6, "Julho" => 7, "Agosto" => 8,
    "Setembro" => 9, "Outubro" => 10, "Novembro" => 11, "Dezembro" => 12
  }.freeze

  def initialize(username:, password:, login_url:, headless: true)
    @username = username
    @password = password
    @login_url = login_url
    @headless = headless
    @browser = nil
  end

  def call
    setup_browser
    login
    navigate_to_calendar
    parse_calendar
  rescue Error
    save_screenshot("error_#{Time.now.strftime("%Y%m%d_%H%M%S")}") if @browser && Rails.env.development?
    raise
  ensure
    @browser&.quit
  end

  def login!
    setup_browser
    login
    self
  end

  def fetch_saldo_disponivel
    url = "#{@login_url.sub(/\/[^\/]*\z/, "")}/ajax_refeicoes.php"

    response = @browser.network.post(
      url,
      headers: {
        "Content-Type" => "application/json; charset=UTF-8",
        "X-Requested-With" => "XMLHttpRequest",
        "Cookie" => cookies
      },
      body: { idsetorconta: 0, acao: "get_refeicoes_compra" }.to_json
    )

    data = JSON.parse(response.body)

    raw = data.dig("saldos", "valordisponivel") ||
      raise("valordisponivel not found in response: #{data.inspect}")

    normalized = raw.to_s.delete(".").tr(",", ".")
    euros = BigDecimal(normalized)
    cents = (euros * 100).to_i

    { euros: euros, cents: cents }
  end

  def cookies
    @browser.cookies.map { |c| "#{c[:name]}=#{c[:value]}" }.join("; ")
  end

  private

  def setup_browser
    @browser = Ferrum::Browser.new(
      timeout: 180,
      process_timeout: 30,
      headless: @headless
    )
  end

  def login
    @browser.goto(@login_url)

    wait_until(60) { @browser.body.include?("AUTENTICAÇÃO") } ||
      raise(LoginError, "Timed out waiting for AUTENTICAÇÃO")

    user_input = wait_until(60) { @browser.at_css("#username") }
    pass_input = wait_until(60) { @browser.at_css("#password") }

    raise(LoginError, "Username input (#username) not found") unless user_input
    raise(LoginError, "Password input (#password) not found") unless pass_input

    safe_type(user_input, @username)
    safe_type(pass_input, @password)

    if (body_node = @browser.at_xpath("//body"))
      safe_click(body_node)
    end

    entrar_btn = @browser.at_xpath("//*[contains(normalize-space(text()), 'Entrar')]")
    raise(LoginError, "Entrar button not found") unless entrar_btn

    safe_click(entrar_btn)

    wait_until(60) { @browser.body.include?("Bem-vindo ao netGIAE.") } ||
      raise(LoginError, "Timed out waiting for 'Bem-vindo ao netGIAE.'")
  end

  def navigate_to_calendar
    refeicoes_node = wait_until(60) do
      @browser.at_xpath("//*[contains(normalize-space(text()), 'Refeições')]")
    end
    raise(NavigationError, "Refeições menu not found") unless refeicoes_node
    safe_click(refeicoes_node)

    aquis_node = wait_until(60) do
      @browser.at_xpath("//*[contains(normalize-space(text()), 'Aquisição')]")
    end
    raise(NavigationError, "Aquisição menu not found") unless aquis_node
    safe_click(aquis_node)

    wait_until(120) do
      body = @browser.body
      body.include?("Aquisição de Refeições") &&
        body.include?("Aquisição de refeições.")
    end || raise(NavigationError, "Timed out waiting for Aquisição de Refeições")
  end

  def parse_calendar
    wait_until(60) do
      Nokogiri::HTML(@browser.body).css("td[data-handler='selectDay']").any?
    end || raise(CalendarParseError, "Timed out waiting for calendar cells")

    html = @browser.body
    doc = Nokogiri::HTML(html)

    day_cells = doc.css("td[data-handler='selectDay']")
    raise(CalendarParseError, "No day cells found") if day_cells.empty?

    header_text = doc.text
    month_name = MONTH_MAP.keys.find { |m| header_text.include?(m) }

    year = Date.today.year
    month = month_name ? MONTH_MAP[month_name] : Date.today.month

    results = []

    day_cells.each do |cell|
      day_text = cell.at_css("a")&.text&.strip
      next unless day_text&.match?(/\A\d+\z/)

      day = day_text.to_i
      date = Date.new(year, month, day)

      next if date.saturday? || date.sunday?
      next if portuguese_holiday?(date)

      classes = cell["class"].to_s.split
      bought = classes.include?("highlight-green")

      results << { date: date, bought: bought }
    end

    results
  end

  def save_screenshot(name)
    return unless @browser

    filename = Rails.root.join("tmp", "#{name}.png")
    @browser.screenshot(path: filename.to_s, full: true)
    Rails.logger.info "[GiaeScraperService] Screenshot saved to #{filename}"
  end

  def wait_until(timeout, interval = 0.3)
    deadline = Time.now + timeout
    until Time.now > deadline
      result = yield
      return result if result
      sleep interval
    end
    nil
  end

  def safe_type(node, text)
    node.focus
    begin
      node.type([ :control, "a" ], :backspace)
    rescue
    end
    node.type(text.to_s)
  end

  def safe_click(node)
    node.click
  rescue Ferrum::CoordinatesNotFoundError
    node.evaluate("this.click()")
  end

  def portuguese_holiday?(date)
    Holidays.on(date, :pt).any?
  end
end
