
# giae_calendar_status.rb
# frozen_string_literal: true

require "ferrum"
require "nokogiri"
require "date"
require "holidays"

USERNAME        = ENV.fetch("GIAE_USERNAME")
PASSWORD        = ENV.fetch("GIAE_PASSWORD")
LOGIN_URL       = ENV.fetch("GIAE_LOGIN_URL")       # e.g. https://aemgn.giae.pt/index.html
ACQUISITION_URL = ENV.fetch("GIAE_AQUISITION_URL")  # not strictly used, we navigate via menu
HEADLESS        = ENV.fetch("GIAE_HEADLESS", "true") != "false"

def log(msg)
  puts "[#{Time.now.strftime("%H:%M:%S")}] #{msg}"
end

def wait_until(timeout: 15, interval: 0.3)
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
  rescue StandardError
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

# Extracts "Carne"/"Peixe" (or nil) from the details panel for the given date
def prato_tipo_for_date(browser, date)
  formatted_date = date.strftime("%d-%m-%Y")

  wait_until(timeout: 10) { browser.body.include?(formatted_date) }

  details_doc = Nokogiri::HTML(browser.body)

  heading = details_doc.at_xpath(
    "//h1[contains(., 'Prato ')] | " \
    "//h2[contains(., 'Prato ')] | " \
    "//h3[contains(., 'Prato ')] | " \
    "//h4[contains(., 'Prato ')] | " \
    "//h5[contains(., 'Prato ')] | " \
    "//h6[contains(., 'Prato ')]"
  )

  return nil unless heading

  text = heading.text.strip
  if text =~ /Prato\s+(\w+)/
    Regexp.last_match(1) # "Carne" or "Peixe"
  else
    nil
  end
end

browser = Ferrum::Browser.new(
  timeout: 120,
  headless: HEADLESS
)

begin
  # 1) Login page (AUTENTICAÇÃO)
  log "Goto login URL: #{LOGIN_URL} (headless=#{HEADLESS})"
  browser.goto(LOGIN_URL)

  log "Waiting for AUTENTICAÇÃO heading"
  wait_until(timeout: 30) { browser.body.include?("AUTENTICAÇÃO") } ||
    abort("Timed out waiting for AUTENTICAÇÃO")

  # 2) Username / password (#username, #password)
  log "Waiting for #username and #password inputs"
  user_input = wait_until(timeout: 30) { browser.at_css("#username") }
  pass_input = wait_until(timeout: 30) { browser.at_css("#password") }
  abort "Username input (#username) not found" unless user_input
  abort "Password input (#password) not found" unless pass_input

  log "Filling username/password"
  safe_type(user_input, USERNAME)
  safe_type(pass_input, PASSWORD)

  # Blur so KO validations see the values
  if (body_node = browser.at_xpath("//body"))
    safe_click(body_node)
  end

  # 3) Entrar
  log "Clicking Entrar"
  entrar_btn = browser.at_xpath("//*[contains(normalize-space(text()), 'Entrar')]")
  abort "Entrar button not found" unless entrar_btn
  safe_click(entrar_btn)

  # 4) Wait for home: “Bem-vindo ao netGIAE.”
  log "Waiting for 'Bem-vindo ao netGIAE.' (up to 60s)"
  wait_until(timeout: 60) { browser.body.include?("Bem-vindo ao netGIAE.") } ||
    begin
      File.write("giae_after_login_timeout.html", browser.body)
      abort("Timed out waiting for 'Bem-vindo ao netGIAE.'; saved giae_after_login_timeout.html")
    end

  # 5) Refeições → Aquisição
  log "Clicking Refeições"
  refeicoes_node = wait_until(timeout: 30) do
    browser.at_xpath("//*[contains(normalize-space(text()), 'Refeições')]")
  end
  abort "Refeições menu not found" unless refeicoes_node
  safe_click(refeicoes_node)

  log "Clicking Aquisição"
  aquis_node = wait_until(timeout: 30) do
    browser.at_xpath("//*[contains(normalize-space(text()), 'Aquisição')]")
  end
  abort "Aquisição menu not found" unless aquis_node
  safe_click(aquis_node)

  log "Waiting for Aquisição de Refeições page"
  wait_until(timeout: 60) do
    body = browser.body
    body.include?("Aquisição de Refeições") &&
      body.include?("Aquisição de refeições.")
  end || begin
    File.write("giae_after_aquisicao_timeout.html", browser.body)
    abort("Timed out waiting for Aquisição de Refeições; saved giae_after_aquisicao_timeout.html")
  end

  # 6) Calendar parsing

  log "Waiting for calendar cells"
  wait_until(timeout: 30) do
    Nokogiri::HTML(browser.body).css("td[data-handler='selectDay']").any?
  end || begin
    File.write("giae_no_calendar.html", browser.body)
    abort("Timed out waiting for calendar; saved giae_no_calendar.html")
  end

  html = browser.body
  doc  = Nokogiri::HTML(html)

  day_cells = doc.css("td[data-handler='selectDay']")
  log "Found #{day_cells.size} day cells in calendar"

  if day_cells.empty?
    File.write("giae_no_day_cells.html", html)
    abort("Still 0 day cells; saved giae_no_day_cells.html for inspection")
  end

  month_map = {
    "Janeiro"  => 1, "Fevereiro" => 2, "Março"     => 3, "Abril"    => 4,
    "Maio"     => 5, "Junho"     => 6, "Julho"     => 7, "Agosto"   => 8,
    "Setembro" => 9, "Outubro"   => 10, "Novembro" => 11, "Dezembro" => 12
  }

  header_text = doc.text
  month_name  = month_map.keys.find { |m| header_text.include?(m) }

  year  = Date.today.year
  month = month_name ? month_map[month_name] : Date.today.month

  log "Analysing calendar for #{month_name || month}/#{year}"

  # Work from a list of day numbers, not nodes
  day_numbers = day_cells.map { |cell| cell.at_css("a")&.text&.strip }.compact

  day_numbers.each do |day_text|
    next unless day_text.match?(/\A\d+\z/)

    day  = day_text.to_i
    date = Date.new(year, month, day)

    next if date.saturday? || date.sunday?
    next if portuguese_holiday?(date)

    # Re-parse current DOM to get state for this day
    current_doc  = Nokogiri::HTML(browser.body)
    current_cell = current_doc.at_xpath(
      "//td[@data-handler='selectDay']/a[normalize-space(text())='#{day_text}']/.."
    )

    unless current_cell
      puts "#{date}: unknown (Prato unknown - day cell not found)"
      next
    end

    classes = current_cell["class"].to_s.split
    bought  = classes.include?("highlight-green")
    status  = bought ? "BOUGHT" : "not bought"

    # Find live Ferrum node and click
    link_node = browser.at_xpath(
      "//td[@data-handler='selectDay']/a[normalize-space(text())='#{day_text}']"
    )

    unless link_node
      puts "#{date}: #{status} (Prato unknown - live link not found)"
      next
    end

    begin
      safe_click(link_node)
    rescue Ferrum::NodeNotFoundError
      puts "#{date}: #{status} (Prato unknown - node became stale)"
      next
    end

    tipo     = prato_tipo_for_date(browser, date) # "Carne", "Peixe" or nil
    tipo_str = tipo || "unknown"

    puts "#{date}: #{status} (Prato #{tipo_str})"
  end
ensure
  browser.quit
end
