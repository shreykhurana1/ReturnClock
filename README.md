# ReturnClock

ReturnClock is a Rails SaaS course project for Columbia University's Engineering
Software as a Service course. It tracks purchases and calculates return deadlines
from store policies. Authentication, database models, and automated tests are
implemented, including a read-only Dashboard and History. Purchase creation,
editing, deletion, status updates, and account settings remain teammate work.

## Prerequisites

- Ruby **3.3.12**, Rails **8.1.4**, and Bundler **2.5.22**; use the checked-in version files.
- PostgreSQL (verified with **18.6**), Git, and libvips.
- A Ruby version manager such as rbenv with ruby-build. No Node/npm or Redis is required.

See [detailed local setup](docs/local-setup.md) for Ruby installation, PostgreSQL
18 installation, native gem dependencies, and troubleshooting.

## Local PostgreSQL setup

On **WSL Ubuntu**, install dependencies and start PostgreSQL inside Ubuntu:

```sh
sudo apt-get update
sudo apt-get install -y build-essential libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libpq-dev libvips-dev postgresql postgresql-contrib
sudo service postgresql start
sudo -u postgres psql -d postgres -c '\du'
```

Only if a role matching your Linux username is missing:

```sh
sudo -u postgres createuser --createdb --no-superuser --no-createrole "$(whoami)"
```

On **macOS with Homebrew**:

```sh
brew install rbenv ruby-build postgresql@18 vips
brew services start postgresql@18
export PATH="$(brew --prefix postgresql@18)/bin:$PATH"
psql -d postgres -c 'SELECT current_user;'
```

Homebrew normally creates your local login role. If it is missing, follow the
[role setup instructions](docs/local-setup.md). Rails uses your OS username and
a local Unix socket by default. Neither suite requires PostgreSQL superuser
privileges. Existing developers should keep their working roles and databases.

## Install and run

Clone the repository and check out the branch agreed with the team (`main` after
integration), then run these commands from the project directory with Ruby 3.3.12:

```sh
git clone https://github.com/shreykhurana1/ReturnClock.git
cd ReturnClock
gem install bundler -v 2.5.22
bundle install
bin/rails db:prepare
RAILS_ENV=test bin/rails db:prepare
bin/rails server
```

Open <http://localhost:3000> and create an account. There are no required seeds or
default credentials. The default databases are `return_clock_development` and
`return_clock_test`. After pulling migrations, rerun `bundle install` and
`bin/rails db:prepare`; do not reset existing data. Keep production credentials
out of your local `DATABASE_URL`. `.env` files are not automatically loaded.

## Test

```sh
bundle exec rspec
bin/rails test
```

Both suites create and roll back their own records. CI runs both suites plus
style/security checks. See [testing notes](spec/README.md) and
[additional checks](docs/local-setup.md#tests-and-checks).

## Git and pull requests

Start new work from an updated, integrated `main`:

```sh
git switch main
git pull --ff-only origin main
git switch -c your-name/feature-name
```

Keep changes focused, coordinate shared files, and add new migrations rather
than editing applied ones. When authorized, commit and push your feature branch,
open a PR into `main`, obtain team review, and wait for CI before merging. Rerun
both suites after resolving integration conflicts. Do not commit secrets or
force-push another teammate's branch.

## Authentication convention

Controllers use **`Current.user`**, not `current_user`. `ApplicationController`
requires authentication by default; public actions explicitly opt out. On public
actions, resume the session (for example with `authenticated?`) before reading
`Current.user`. Scope purchase/policy queries through that user and never permit
`user_id` from a form.

## Team references

- [Architecture, model rules, ownership, and responsibilities](docs/architecture.md)
- [Heroku setup, environment variables, deployment steps, and limitations](docs/deployment.md)
- [Navigation, purchase classification, and acceptance criteria](docs/navigation.md)

Purchase CRUD, Cucumber stories, and final UI decisions remain with their assigned
teammates. The current authentication styling implements only the agreed layout
requirements. Production password reset stays disabled until email delivery is
configured. The read-only pages do not add purchase mutation routes.
