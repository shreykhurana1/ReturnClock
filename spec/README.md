# Automated tests

RSpec Rails 8.0.x covers models and authentication requests. The original
Minitest suite is retained, and CI runs both suites.

With PostgreSQL running and your local database role configured:

```sh
bundle install
RAILS_ENV=test bin/rails db:test:prepare
bundle exec rspec
bin/rails test
bin/rails test:system
bin/rubocop
```

Run one area with `bundle exec rspec spec/models` or
`bundle exec rspec spec/requests`. RSpec prints a random seed; use
`bundle exec rspec --seed NUMBER` to reproduce an ordering failure.

Both suites create records directly with Active Record and roll back each
test. No factory or database-cleaning gem is required. Request specs exercise
the real signup/session routes, signed cookies, and authentication callbacks.

Deadlines are saved snapshots of purchase date plus policy window. Editing a
policy preserves existing deadlines; changing a purchase's date or policy
recalculates its deadline. Policy ownership cannot change while purchases
reference it.

Ownership specs cover model validation and owner-scoped associations. Future
purchase/policy controllers must look up records through `Current.user` and
must not permit `user_id`; add request authorization tests when CRUD is built.

The system-test directory is tracked so the existing CI target can run before
browser tests are added. It currently contains no system tests.

Minitest creates users in controller setup and creates users, policies, then
purchases in model tests. It does not automatically load the generated YAML
files in `test/fixtures`; those remain as sample data. This avoids Rails'
bulk fixture loader, which attempts to disable PostgreSQL foreign-key
triggers. Both suites work with a normal local database role while leaving
foreign-key checks enabled. Test passwords are `Password1!`.
