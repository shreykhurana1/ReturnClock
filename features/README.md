# Acceptance tests

Run `bundle exec cucumber` with local PostgreSQL running. No Rails server or
browser installation is needed. Run one scenario with, for example,
`bundle exec cucumber features/authentication.feature:6`.

Sophia can add feature files under `features/` and reuse the steps in
`step_definitions/authentication_steps.rb`. Group new steps by feature as needed.
Describe user actions and visible results; keep detailed validation and model
edge cases in RSpec. Add stories only for implemented functionality.

`support/env.rb` loads Rails in the test environment. `support/hooks.rb` uses
Rails' transaction setup/teardown to roll back each scenario's records, without
loading YAML fixtures or disabling foreign keys. Capybara resets cookies between
scenarios. Create prerequisite records with Active Record in Given steps; perform
the behavior being tested through the page.

The RackTest driver does not execute JavaScript or test CSS layout. These
scenarios cover server-rendered behavior. Browser/JavaScript scenarios would need
a browser driver and a review of test isolation before adding `@javascript`.
