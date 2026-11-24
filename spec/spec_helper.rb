require "simplecov"

SimpleCov.start "rails" do
  enable_coverage :branch
  cover "{app,lib}/**/*.{rb,rake}"
  skip "/spec/"
  skip "/test/"
  skip "/config/"
  skip "/db/"
  skip "/vendor/"
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.order = :random
  Kernel.srand config.seed
end
