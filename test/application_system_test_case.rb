require "test_helper"

# Keep cosmetic transitions and smooth scrolling from moving Selenium's click targets.
Capybara.disable_animation = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
  end

  def after_teardown
    # A fresh browser isolates cookies/storage and avoids Capybara's wildcard-origin cleanup,
    # which newer Chrome versions reject. Quit before Rails resets Capybara's sessions.
    Capybara.current_session.driver.quit
  ensure
    super
  end
end
