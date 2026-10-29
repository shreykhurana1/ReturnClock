Before do
  setup_fixtures
end

After do
  teardown_fixtures
ensure
  Current.reset
end
