# frozen_string_literal: true

# Verbose debugging for GIAE integration
# Enable with: GIAE_DEBUG=1 rails server
# Or: fly secrets set GIAE_DEBUG=1 --app giae-calendar

module GiaeDebug
  ENABLED = ENV.fetch("GIAE_DEBUG", "0") == "1"

  def self.log(message, data = nil)
    return unless ENABLED

    timestamp = Time.current.strftime("%Y-%m-%d %H:%M:%S.%L")
    prefix = "[GIAE_DEBUG #{timestamp}]"

    if data
      Rails.logger.info "#{prefix} #{message}: #{data.inspect}"
    else
      Rails.logger.info "#{prefix} #{message}"
    end
  end

  def self.log_request(description, method, url, headers, body = nil, cookies = nil)
    return unless ENABLED

    log("=" * 80)
    log("REQUEST: #{description}")
    log("#{method} #{url}")
    log("Headers", headers)
    log("Cookies", cookies) if cookies
    log("Body", body) if body
  end

  def self.log_response(description, response)
    return unless ENABLED

    log("RESPONSE: #{description}")
    log("Status", response.code)

    headers = {}
    response.each_header { |k, v| headers[k] = v }
    log("Response Headers", headers)

    if response["set-cookie"]
      log("Set-Cookie", response.get_fields("set-cookie"))
    end

    body_preview = response.body.to_s[0..500]
    log("Body Preview", body_preview)
    log("=" * 80)
  end

  def self.log_error(description, error)
    return unless ENABLED

    log("ERROR: #{description}")
    log("Error Class", error.class.name)
    log("Error Message", error.message)
    log("Backtrace", error.backtrace.first(5)) if error.backtrace
  end
end
