# ReturnClock

ReturnClock tracks purchases, store return policies, and return deadlines through Dashboard and History.
Use **Ruby 3.3.12**, **Rails 8.1.4**, **Bundler 2.5.22**, and **PostgreSQL 18** (tested with 18.6), plus Git and libvips.

## Local setup

- **macOS:** run `brew install postgresql@18 vips`, then `brew services start postgresql@18`.
  Homebrew normally creates your login role. Add PostgreSQL tools to your shell: `export PATH="$(brew --prefix postgresql@18)/bin:$PATH"`.
- **Windows/WSL Ubuntu:** install PostgreSQL 18 using the [official Ubuntu instructions](https://www.postgresql.org/download/linux/ubuntu/).
  Run `sudo apt-get update`, then `sudo apt-get install -y build-essential git libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libpq-dev libvips-dev` and `sudo service postgresql start`.
- **First-time WSL database role:** check `sudo -u postgres psql -d postgres -c '\du'`; only if your Linux username is missing, run `sudo -u postgres createuser --createdb --no-superuser --no-createrole "$(whoami)"`.

```sh
git clone https://github.com/shreykhurana1/ReturnClock.git
cd ReturnClock
gem install bundler -v 2.5.22
bundle install
bin/rails db:prepare
RAILS_ENV=test bin/rails db:prepare
bin/rails server
```
Open <http://localhost:3000> and create an account. Keep production credentials out of your local `DATABASE_URL`.

## Run tests

```sh
bundle exec rspec
bin/rails test
bundle exec cucumber
```

## Contribute

```sh
git switch main
git pull --ff-only origin main
git switch -c your-name/feature-name
git add path/to/changed-file
git commit -m "Describe the change"
git push -u origin your-name/feature-name
gh pr create --base main --fill
```
The last command uses GitHub CLI; alternatively choose **Compare & pull request** on GitHub. Request team review and wait for CI.
Scope records through `Current.user`, e.g. `Current.user.purchases`; never accept `user_id` from forms.

## Heroku

After team approval of app ownership and paid plans, replace the placeholders below. For an existing app, use `heroku git:remote --app YOUR_APP` instead of creating another app or database.
Set `SECRET_KEY_BASE` privately (and `RAILS_MASTER_KEY` if encrypted credentials are needed); the PostgreSQL add-on supplies `DATABASE_URL`.
```sh
heroku login
heroku create YOUR_APP --stack heroku-24 --buildpack heroku/ruby
heroku addons:create heroku-postgresql:APPROVED_POSTGRES_PLAN --app YOUR_APP
heroku config:set APP_HOST=ACTUAL_HOSTNAME SOLID_QUEUE_IN_PUMA=true WEB_CONCURRENCY=0 RAILS_MAX_THREADS=3 DB_POOL=10 --app YOUR_APP
git push heroku main
heroku ps:scale web=1:APPROVED_DYNO_TYPE --app YOUR_APP
heroku logs --tail --app YOUR_APP
```
The Procfile runs migrations during release; check them with `heroku run bin/rails db:migrate:status --app YOUR_APP`.
