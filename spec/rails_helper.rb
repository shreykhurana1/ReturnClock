require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
abort "RSpec must run in the test environment" unless ENV["RAILS_ENV"] == "test"
require_relative "../config/environment"
require "rspec/rails"

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # Each example rolls back its own records; fixtures are loaded only when requested.
  config.fixture_paths = [ Rails.root.join("test/fixtures") ]
  config.use_transactional_fixtures = true
  config.include ActiveSupport::Testing::TimeHelpers
  config.filter_rails_from_backtrace!
end
