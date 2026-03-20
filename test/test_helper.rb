ENV["RAILS_ENV"] ||= "test"

# Start SimpleCov before loading the Rails environment
if ENV["COVERAGE"]
  require "simplecov"

  # Disable parallel tests when running coverage to get accurate results
  ENV["PARALLEL_WORKERS"] = "1"

  SimpleCov.start "rails" do
    add_filter "/test/"
    add_filter "/config/"
    add_filter "/vendor/"
    add_filter "/bin/"
    add_filter "/db/"

    # Track uncovered lines
    enable_coverage :branch

    # Minimum coverage threshold (adjust as needed)
    # minimum_coverage 80

    # Group files by type
    add_group "Models", "app/models"
    add_group "Controllers", "app/controllers"
    add_group "Jobs", "app/jobs"
    add_group "Services", "app/services"
    add_group "Helpers", "app/helpers"
    add_group "Mailers", "app/mailers"
    add_group "Lib", "lib"
  end
end

require_relative "../config/environment"
require "rails/test_help"

# Require mocha for mocking
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers (disabled when running coverage)
    parallelize(workers: ENV["COVERAGE"] ? 1 : :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all
  end
end
