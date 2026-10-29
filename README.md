# ReturnClock

ReturnClock is a Ruby on Rails SaaS course project for Columbia University's
Engineering Software as a Service course. It helps users track purchases and
calculate the last day to return an item using their store's return policy.

## Current implementation

- Signup, login, logout, password hashing, email normalization, and validation.
- Database-backed sessions using Rails' built-in authentication system.
- User-owned store policies and purchases, with model validations and foreign keys.
- Automatic return deadlines, six purchase statuses, and a `days_left` calculation.
- RSpec model/request tests and the retained Minitest suite, both run by CI.
- Heroku configuration for one PostgreSQL database, HTTPS, and Solid services.

Purchase CRUD screens/endpoints, Cucumber stories, the final UI, and email
reminders are pending teammate/future work. This repository is prepared for
Heroku; this documentation does not mean an application has been deployed.
Password-reset code is retained and tested locally but disabled in production
until real email delivery is configured.

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

Until the authentication work is merged, use `git switch shrey/authentication`
to work with that implementation. After merging, new work should start from
an updated `main`.

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
need internet access. See [the testing notes](spec/README.md) for focused runs.

GitHub Actions runs RSpec and Minitest plus style/security checks on pull requests
and pushes to `main`. Avoid using `bin/ci` against valuable local data without
reviewing `config/ci.rb`: its generated seed check replants the **test** database.

## Database and authentication handoff

| Model | Relationships and important rules |
| --- | --- |
| `User` | Has many sessions, purchases, and store policies. Emails are stripped/lowercased and unique. Passwords need at least 8 characters, uppercase/lowercase letters, a digit, and a special character; BCrypt limits input to 72 bytes. |
| `Session` | Belongs to a user. The browser holds a signed, HttpOnly, SameSite=Lax session-ID cookie. Logout deletes the matching server-side session. |
| `StorePolicy` | Belongs to a user; has many purchases. Store name is unique per user (case-sensitive); `window_days` is a positive integer. Referenced policies cannot be deleted or transferred to another owner. |
| `Purchase` | Belongs to a user and a store policy owned by that user. Requires an item name, positive decimal price, purchase date, deadline, and allowed status. |

Allowed statuses are `active`, `keeping`, `returning`, `shipped_back`,
`refund_pending`, and `refunded`. They are model-validated strings, not a Rails
enum; no transition workflow is enforced. Foreign keys, required columns,
unique indexes, and positive price/window checks are defined in the database.
Status membership and matching purchase/policy ownership are model validations;
bulk SQL methods bypass them.

A purchase's deadline is `purchase_date + store_policy.window_days`, using
calendar days. Creation calculates it; changing the purchase date or selected
policy recalculates it. Editing a saved policy does **not** update existing
purchase deadlines, including on unrelated purchase edits. New purchases use
the edited window. `days_left` compares the stored deadline with `Date.current`
and can be negative. Rails currently uses UTC; a user-specific time zone and
inclusive/exclusive retailer policy variations are not implemented. Future
CRUD should treat `return_by` as calculated rather than permitting arbitrary input.

`ApplicationController` includes the existing `Authentication` concern and
requires login by default. Controllers obtain the signed-in user through
`Current.user`; there is no general `current_user` helper. Public actions must
explicitly call `allow_unauthenticated_access`. Views can use `authenticated?`.
On a public action, `Current.user` is available only after the session has been
resumed (for example, by calling `authenticated?`).

For future purchase/policy endpoints, scope all reads and writes to the user:

```ruby
purchase = Current.user.purchases.find(params[:id])
policy = Current.user.store_policies.find(permitted_params[:store_policy_id])
purchase = Current.user.purchases.build(permitted_params)
```

Do not permit `user_id`, use unscoped `Purchase.find`, or return another user's
records. Add two-user request authorization tests with CRUD. The existing model
specs verify ownership rules and scoped associations; they do not prove the
security of endpoints that have not yet been implemented.

## Team workflow and responsibilities

| Area | Owner/scope |
| --- | --- |
| Authentication, models/schema, RSpec, README, deployment preparation | Shrey / `shrey/authentication` |
| Purchase CRUD | Teammate implementation |
| Cucumber stories | Teammate implementation |
| UI | Teammate implementation |

For a new task after this branch is merged:

```sh
git switch main
git pull --ff-only origin main
git switch -c your-name/feature-name
```

Keep PRs focused. Coordinate changes to shared models, routes, and schema;
add migrations rather than modifying another person's applied migration.
Include tests, setup/migration notes, and any changed environment variables.
Push your feature branch, open a PR into `main`, obtain team review, and wait
for CI before merging. Incorporate `origin/main` into a feature branch before
integration, resolve conflicts, and rerun both suites. Do not force-push another
person's branch or merge directly into `main` without review.

For the current branch, review the complete `shrey/authentication` diff against
`main`, commit/push only after approval, and open the PR from that branch.
Teammates should base dependent work on it only by agreement until it is merged.

## Heroku deployment preparation

### Runtime design

The prepared path uses a classic Ruby buildpack on a Cedar/`heroku-24` app,
one web dyno, and **one Heroku PostgreSQL add-on**. No Redis, scheduler add-on,
or separate worker dyno is required for the current setup. Heroku account,
application ownership, region, dyno type, database plan, and costs must be
approved before creating or provisioning anything. Plan names/prices and
runtime availability must be checked at deployment time.

All application, cache, queue, and cable tables share the primary connection.
`20261028200000_create_solid_service_tables.rb` contains the installed Solid
schemas as an additive, reversible Rails migration. Ordinary `db:migrate`
initializes them; `db/schema.rb` also contains them for new database setup.
The separate generated `cache_schema.rb`, `queue_schema.rb`, and `cable_schema.rb`
are superseded. Do not run Solid installer/schema-load commands on an existing
application database; future Solid gem upgrades may need new migrations.

The `Procfile` defines:

```text
release: bundle exec rails db:migrate
web: bundle exec puma -C config/puma.rb
```

The release step runs pending migrations before the new release starts.
`SOLID_QUEUE_IN_PUMA=true` starts the queue supervisor, dispatcher, scheduler,
and one job-worker thread in the web process using async mode. This shares the
web dyno's resources; keep `WEB_CONCURRENCY=0` initially and watch memory and
connection usage. The production connection pool defaults to 10 (`DB_POOL`).
If the selected dyno sleeps or is stopped, jobs wait until it runs again;
this is unsuitable for reminders that must run at a specific time. An always-on
process or a separate worker would be a later, explicitly approved hosting decision.

Production enforces HTTPS and secure cookies using Rails' SSL middleware.
Heroku's `X-Forwarded-Proto` is preserved (`assume_ssl` is false) so HTTP requests
redirect and proxied HTTPS requests avoid redirect loops. `APP_HOST` restricts
accepted hostnames when set and supplies future HTTPS email-link generation.
Use the actual hostname shown by Heroku, which may contain a generated suffix.

### Environment variables and secrets

| Variable | Requirement |
| --- | --- |
| `DATABASE_URL` | Required in production; supplied by the approved PostgreSQL add-on. Do not hard-code or print its credentials. |
| `SECRET_KEY_BASE` | Required production secret, supplied by the platform or set privately; stable across restarts. Generate a value with `bin/rails secret` only when configuring the app. |
| `RAILS_MASTER_KEY` | Needed only if using the repository's encrypted credentials. Keep private and obtain from the project owner; the current runtime uses no custom encrypted credentials. |
| `APP_HOST` | Set to the app's actual public hostname, without a scheme or path. |
| `SOLID_QUEUE_IN_PUMA` | Set to the literal `true` for the single-dyno queue setup. |
| `WEB_CONCURRENCY` | Set to `0` initially for one Puma process. |
| `RAILS_MAX_THREADS` | Use `3` initially. |
| `DB_POOL` | Defaults to `10`; coordinate changes with the chosen plan's connection limit and process count. |
| `PORT`, `RAILS_ENV` | Set by Heroku. |

Configure secrets privately in the Heroku dashboard; do not commit keys, paste
them into a PR, or use `SECRET_KEY_BASE_DUMMY` in a deployed app. A dummy secret
is only for local/build checks. The Gemfile pins Ruby from `.ruby-version`;
confirm Ruby 3.3.12 is available on the selected stack before deploying.

### Remaining deployment steps — manual, after approval

These are instructions, not actions already taken. Replace all uppercase
placeholders. **Stop before the create/provision/scale commands until the
team approves infrastructure and ongoing cost.**

1. Merge the reviewed PR into `main` after CI passes. Update your local `main`.
2. Install/login to the Heroku CLI. Choose the app owner, region, dyno plan,
   and PostgreSQL plan. If an approved app already exists, attach its remote
   and inspect its configuration rather than creating a duplicate.
3. For a new, approved classic-buildpack app:

   ```sh
   heroku login
   heroku create YOUR_APP_NAME --stack heroku-24 --buildpack heroku/ruby
   heroku addons:create heroku-postgresql:APPROVED_POSTGRES_PLAN --app YOUR_APP_NAME
   heroku addons:wait --app YOUR_APP_NAME
   heroku domains --app YOUR_APP_NAME
   ```

   For an existing approved app, use
   `heroku git:remote --app YOUR_APP_NAME` instead of `heroku create`.
   Check existing add-ons before provisioning a database.

4. Set `SECRET_KEY_BASE` privately (and `RAILS_MASTER_KEY` only if needed),
   confirm the add-on supplied `DATABASE_URL`, then set non-secret settings:

   ```sh
   heroku config:set APP_HOST=ACTUAL_HEROKU_HOSTNAME SOLID_QUEUE_IN_PUMA=true WEB_CONCURRENCY=0 RAILS_MAX_THREADS=3 DB_POOL=10 --app YOUR_APP_NAME
   ```

5. Deploy the reviewed `main` branch and scale using the approved dyno type:

   ```sh
   git push heroku main
   heroku ps:scale web=1:APPROVED_DYNO_TYPE --app YOUR_APP_NAME
   heroku releases --app YOUR_APP_NAME
   heroku logs --tail --app YOUR_APP_NAME
   ```

   The release phase applies migrations, including the Solid tables. If it
   fails, inspect release logs and fix the cause; do not reset the database.
   If deploying over existing production data, arrange an appropriate backup
   before migration. No development data is copied to Heroku by these steps.

6. Check HTTP redirects to HTTPS, then test signup, login, logout, and secure
   session-cookie flags over HTTPS. Confirm `/passwords/new` returns 404 and
   the reset link is absent. Check queue startup logs and migration status:

   ```sh
   heroku run bin/rails db:migrate:status --app YOUR_APP_NAME
   ```

### Known limitations and next work

- Purchase CRUD, final UI, and Cucumber stories remain teammate work.
- Production password resets are deliberately disabled by configuration, and
  direct reset requests return 404. SMTP, a verified sender, and actual delivery
  have not been configured. Before enabling the flag in `production.rb`, configure
  delivery and `APP_HOST`, replace the placeholder mail sender, test delivery and
  token/session behavior, and review the full reset flow. There is no environment
  toggle that silently enables an unconfigured mailer.
- Email reminders are not implemented. Solid Queue is ready for future jobs;
  enqueue through Active Job after the relevant database transaction commits.
- Uploads are not implemented. The generated local Active Storage service is
  unsuitable for persistent Heroku uploads; add approved external storage only
  if that feature is needed. Image variants would also require libvips in the
  runtime; its absence currently emits a warning but does not block this app.
- UTC dates, case-sensitive store names, unrestricted status transitions, and
  model-level ownership/status checks should be understood when building CRUD.
- Session expiration/cleanup and email-address verification are not implemented.
- One shared database and jobs in the web process suit a small course application,
  but database storage, connections, dyno memory, and reliability still need monitoring.

References: [Heroku Rails guide](https://devcenter.heroku.com/articles/getting-started-with-rails8),
[release phase](https://devcenter.heroku.com/articles/release-phase),
[Heroku HTTPS](https://help.heroku.com/J2R1S4T8/can-heroku-force-an-application-to-use-ssl-tls),
[Solid Queue single-database setup](https://github.com/rails/solid_queue#single-database-configuration),
[Solid Cache connections](https://github.com/rails/solid_cache#connection-configuration),
and [Heroku's ephemeral filesystem](https://devcenter.heroku.com/articles/dyno-isolation).
