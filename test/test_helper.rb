ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Create records in each test's setup instead of bulk-loading fixtures.
    # Foreign keys stay enabled, and Rails rolls back each test's records.
  end
end
