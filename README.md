# ReturnClock

ReturnClock is a Columbia Engineering SaaS course project that tracks purchases
and calculates return deadlines from store policies. Authentication, read-only
Dashboard/History, store-policy and purchase creation, and automated tests work
today. Purchase editing/deletion/status updates and account editing remain pending.

## Prerequisites

Use **Ruby 3.3.12**, **Rails 8.1.4**, Bundler **2.5.22**, Git, PostgreSQL
(verified with 18.6), and libvips. Node/npm and Redis are not required.
Follow [macOS / Windows WSL setup](docs/local-setup.md) for packages, Ruby,
PostgreSQL startup, and a local login role with `CREATEDB`; tests need no superuser.

## Install and start

Run these in Terminal on macOS or Ubuntu on WSL, after PostgreSQL is ready:

```sh
git clone https://github.com/shreykhurana1/ReturnClock.git
cd ReturnClock
gem install bundler -v 2.5.22
bundle install
bin/rails db:prepare
RAILS_ENV=test bin/rails db:prepare
bin/rails server
```

Use the team's agreed branch until integration into `main`. Open
<http://localhost:3000> and create an account; no seeds or default login are needed.
Rails uses your OS username for local PostgreSQL and the databases
`return_clock_development` / `return_clock_test`. Keep production URLs out of your
local `DATABASE_URL`. After pulling migrations, rerun `bundle install` and
`bin/rails db:prepare`; preserve existing data.

## Run tests

```sh
bundle exec rspec
bin/rails test
bundle exec cucumber
```

The suites create and roll back their own records. GitHub CI runs all three plus
lint/security checks. See [acceptance-test notes](features/README.md) for adding stories.

## Contribute

Start from the updated, integrated `main`; coordinate shared files with teammates:

```sh
git switch main
git pull --ff-only origin main
git switch -c your-name/feature-name
# Make changes and run the tests above.
git add path/to/changed-file
git commit -m "Describe the change"
git push -u origin your-name/feature-name
```

On GitHub, choose **Compare & pull request** for your branch, targeting `main`.
Request team review and wait for CI before merging. Never commit credentials.

## Integration notes

Use **`Current.user`** in authenticated controllers and scope records through it,
e.g. `Current.user.purchases` and `Current.user.store_policies`. Never accept an
owner's `user_id` from a form. Controllers require authentication by default.
See [architecture and ownership](docs/architecture.md), [navigation and team
handoff](docs/navigation.md), and [Heroku deployment](docs/deployment.md).
