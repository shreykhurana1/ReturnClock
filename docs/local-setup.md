# Detailed local setup and checks

[Quick start](../README.md) · [Testing notes](../spec/README.md)

## Technologies and prerequisites

| Component | Project configuration |
| --- | --- |
| Ruby | 3.3.12, pinned in `.ruby-version` and read by `Gemfile` |
| Rails | 8.1.4 in `Gemfile.lock` |
| Bundler | 2.5.22 in `Gemfile.lock` |
| Database | PostgreSQL; development verified with 18.6 |
| Server/assets | Puma, Propshaft, import maps, Turbo, Stimulus |
| Authentication | Rails authentication concern and BCrypt |
| Background services | Solid Cache, Solid Queue, Solid Cable; no Redis required |
| Tests/checks | RSpec Rails, Minitest, RuboCop, Brakeman, Bundler Audit |

Install Git, a Ruby version manager such as rbenv with ruby-build, PostgreSQL
server/client/development headers, and libvips. Import maps mean the current
application does not need a Node/npm asset-build step. Use the same PostgreSQL
major version across the team where practical.

## Local setup

### 1. Clone and choose a branch

```sh
git clone https://github.com/shreykhurana1/ReturnClock.git
cd ReturnClock
git switch main
```

If the required implementation is still awaiting integration, use the branch
agreed with the team. Once merged, start new work from an updated `main`.

### 2. Install system dependencies

**WSL Ubuntu** — run these inside Ubuntu, not Windows PowerShell:

```sh
sudo apt-get update
sudo apt-get install -y build-essential git libssl-dev libreadline-dev \
  zlib1g-dev libyaml-dev libffi-dev libpq-dev libvips-dev \
  postgresql postgresql-contrib
sudo service postgresql start
```

Ubuntu's package supplies its distribution's PostgreSQL version. For the team's
PostgreSQL 18 setup, use the official [PostgreSQL Ubuntu repository instructions](https://www.postgresql.org/download/linux/ubuntu/).
Do not replace an existing cluster just to follow these instructions.

The default local Rails connection uses a Unix socket and your Linux username.
For a **new developer only**, check whether that PostgreSQL role exists:

```sh
sudo -u postgres psql -d postgres -c '\du'
```

If your username is absent, create a normal login role that can create its own
local development/test databases:

```sh
sudo -u postgres createuser --createdb --no-superuser --no-createrole "$(whoami)"
```

Skip role creation if it already exists. Existing developers should not change
permissions or run Rails as `postgres`. Neither test suite requires superuser
privileges.

**macOS with Homebrew**:

```sh
brew install rbenv ruby-build postgresql@18 vips
brew services start postgresql@18
export PATH="$(brew --prefix postgresql@18)/bin:$PATH"
psql -d postgres -c 'SELECT current_user;'
```

Homebrew normally initializes a role matching your macOS username. If that
connection fails because the role is missing, have the administrator of that
local installation create a login role with `CREATEDB`, without superuser or
role-management privileges (replace `LOCAL_ADMIN_ROLE` with that installation's
existing administrator):

```sh
createuser --username=LOCAL_ADMIN_ROLE --createdb --no-superuser --no-createrole "$(whoami)"
```

Skip this if the role already exists. If another PostgreSQL installation already owns
port 5432, use that installation or resolve the port conflict first. See the
[Homebrew PostgreSQL formula](https://formulae.brew.sh/formula/postgresql@18).

### 3. Install Ruby and gems

Configure rbenv for your shell using its [installation instructions](https://github.com/rbenv/rbenv#installation),
then, from the repository:

```sh
rbenv install -s "$(cat .ruby-version)"
rbenv local "$(cat .ruby-version)"
ruby --version
gem install bundler -v 2.5.22
bundle install
```

If `pg` cannot find PostgreSQL headers on macOS:

```sh
bundle config set --local build.pg --with-pg-config="$(brew --prefix postgresql@18)/bin/pg_config"
bundle install
```

### 4. Prepare the databases and start Rails

```sh
bin/rails db:prepare
RAILS_ENV=test bin/rails db:prepare
bin/rails server
```

Visit <http://localhost:3000>. Default databases are `return_clock_development`
and `return_clock_test`, as defined in `config/database.yml`. `db:prepare`
creates a missing database or applies pending migrations; do not substitute
`db:reset`, `db:drop`, or `db:seed:replant` on a database containing useful data.
There is no required seed data or default login; create an account through signup.

An exported `DATABASE_URL` overrides the corresponding Rails connection. Do not
leave a production URL exported while running local commands. If you need TCP
or password authentication, configure your local environment explicitly without
committing credentials. Development/test authentication works without sharing
`config/master.key`; obtain that key privately only when encrypted credentials
are actually needed. `.env` files are ignored by Git but are not automatically
loaded by the current app; export variables in your shell when needed.

After pulling a change that adds migrations, rerun `bundle install` and
`bin/rails db:prepare`. Do not edit migrations already shared with teammates;
add new migrations and include the regenerated `db/schema.rb` in the PR.

## Tests and checks

If pages lose their styling after a local production asset build, stop Rails,
run `bin/rails assets:clobber`, and restart the server. A generated
`public/assets/.manifest.json` makes Propshaft use the precompiled files even
in development, so later source CSS edits will not appear until it is cleared.
This command removes generated assets only; it does not change database data.

With PostgreSQL running:

```sh
bundle exec rspec
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit check --update
bin/importmap audit
```

Both suites create records through Active Record and roll back test changes.
Minitest does not automatically bulk-load the generated YAML sample fixtures,
so PostgreSQL foreign-key triggers stay enabled. `test:system` currently has no
browser tests; a successful empty run is not browser coverage. Audit commands
need internet access. See [the testing notes](../spec/README.md) for focused runs.

GitHub Actions runs RSpec and Minitest plus style/security checks on pull requests
and pushes to `main`. Avoid using `bin/ci` against valuable local data without
reviewing `config/ci.rb`: its generated seed check replants the **test** database.
