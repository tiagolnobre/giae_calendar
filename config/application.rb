require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module GiaeCalendar
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.active_record.encryption.enabled = true

    config.i18n.default_locale = :en
    config.i18n.available_locales = [ :pt, :en ]

    config.giae_login_url = ENV.fetch("GIAE_LOGIN_URL", "https://aemgn.giae.pt/index.html")
  end
end
