# Heroku deployment

[Quick start](../README.md) · [Architecture](architecture.md)

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
