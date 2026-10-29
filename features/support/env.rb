ENV["RAILS_ENV"] ||= "test"
abort "Cucumber must run in the test environment" unless ENV["RAILS_ENV"] == "test"

require "cucumber/rails"
require "rspec/expectations"

World(RSpec::Matchers)

# These scenarios exercise Rails forms and navigation without a browser or JavaScript.
Capybara.default_driver = :rack_test
ActionController::Base.allow_rescue = false

# Use Rails' existing transaction support instead of an additional cleaning gem.
# No YAML fixtures are loaded, so PostgreSQL foreign-key checks stay enabled.
Cucumber::Rails::Database.autorun_database_cleaner = false
Cucumber::Rails::World.use_transactional_tests = true
Cucumber::Rails::World.fixture_table_names = []
