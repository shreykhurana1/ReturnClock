Before do
  # Keep relative deadlines stable across midnight and future test runs.
  travel_to(Time.zone.local(2026, 11, 9, 12))
  setup_fixtures
end

After do
  teardown_fixtures
ensure
  travel_back
  Current.reset
end
