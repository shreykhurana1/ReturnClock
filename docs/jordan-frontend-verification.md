# Iteration 1 frontend verification record

Verified locally on 2026-11-08 after applying dependency security patches.
This record separates local evidence from the status of GitHub Actions and
from purchase CRUD functionality that still needs backend integration.

## Application and delivery scope

- Repository: `shreykhurana1/ReturnClock`.
- Branch: `iteration1-frontend`.
- Integration base: `97725000d228032afd108942b5055e531ec91220`.
- The input delivery was `263a61dd5cc5b26c8d37810976c9f7f3789fbbbf`.
  Application source and tests are unchanged from that input. This repair
  changes the dependency lockfile and accompanying version/review documentation.
- The delivery retains one frontend commit after the base, authored and committed
  by `findjordanwoods`, with subject `Iteration 1 frontend`. Use `git rev-parse HEAD`
  to identify the delivery SHA after the repair is folded into that commit.
- The UI and code comments are English. There is no language switch or Chinese
  locale; former `lang=zh` parameters are ignored.
- Controllers/authentication concerns, models, routes, schema, database and
  deployment configuration, `Gemfile` constraints and CI workflow are unchanged
  from the base. The deliberate dependency exception is documented below.

See the [handoff](jordan-frontend-handoff.md) for current behavior and backend
interfaces, and the [review notes](jordan-frontend-pr-review.md) for review scope.

## Dependency security repair

The supplied PR #9 CI log reported a failing Bundler Audit step in `scan_ruby`.
A fresh local audit with an updated advisory database reproduced vulnerable
versions and also identified affected Rails components, Loofah and Addressable.

The conservative patch update was:

```sh
bundle update rails nokogiri rack rails-html-sanitizer loofah addressable --conservative --patch --strict
```

| Gem or component group | Before | Verified patched version |
| --- | --- | --- |
| Rails and its matching components | 8.1.4 | 8.1.4.1 |
| Nokogiri | 1.19.4 | 1.19.7 |
| Rack | 3.2.7 | 3.2.8 |
| rails-html-sanitizer | 1.7.1 | 1.7.2 |
| Loofah | 2.25.2 | 2.25.3 |
| Addressable | 2.9.0 | 2.9.2 |

Only these five supporting gems and the thirteen version-coupled Rails gems
changed. The existing lockfile platform list, declared dependencies, Ruby and
Bundler versions were preserved. No vulnerability exclusions, disabled checks,
application workarounds or schema changes were added.

Official repair references include the
[Rails security advisory](https://github.com/rails/rails/security/advisories/GHSA-wm3x-v3qw-4jh3),
[Nokogiri advisory](https://github.com/sparklemotion/nokogiri/security/advisories/GHSA-3w22-6jfg-527w),
[Rack advisory](https://github.com/rack/rack/security/advisories/GHSA-5v64-555j-wjxm), and
[rails-html-sanitizer advisory](https://github.com/rails/rails-html-sanitizer/security/advisories/GHSA-cpgf-5mjf-73p7).
The full advisory database was checked rather than only those four examples.

## Environment and isolation

The verified environment is WSL Ubuntu, Ruby 3.3.12, Rails 8.1.4.1, Bundler
2.5.22 and PostgreSQL 16. The installed bundle satisfies the updated lockfile.
Commands used `rbenv exec` in the noninteractive WSL shell.

All database-dependent test commands explicitly used `RAILS_ENV=test` and the
dedicated local database `return_clock_submit2_en_test_20261108`.
Browser checks used the separate preview database
`return_clock_submit2_en_preview_20261108`. No production connection or reset
of another application's database was used.

The application's own loopback preview at `http://127.0.0.1:3215` was restarted
to load the patched bundle before browser checks. Other preview services were
not restarted. The preview account is local; no shared account or password is
seeded or committed. Teammates should prepare their own database and register.

## Fresh local results after dependency updates

| Check | Result | Exit code |
| --- | --- | --- |
| `ruby bin/bundler-audit check --update` | No vulnerabilities found | 0 |
| `ruby bin/brakeman --no-pager` | Brakeman 8.1.0; 0 errors and 0 security warnings | 0 |
| `ruby bin/importmap audit` | No vulnerable packages found | 0 |
| `bundle exec rspec` | 155 examples, 0 failures; seed 62889 | 0 |
| `bundle exec cucumber features --publish-quiet` | 6 scenarios and 54 steps passed | 0 |
| `bundle exec rake test` | 14 runs, 60 assertions, 0 failures/errors/skips; seed 35147 | 0 |
| `ruby bin/rubocop -f github` | No offenses reported | 0 |
| `bundle exec rake test:system` | 0 runs and 0 assertions; there are no system test cases | 0 |

The zero-case system task is recorded for parity with the workflow; it is not
claimed as automated browser coverage. Real browser checks are listed below.
Rake runs the same Rails/Minitest suite without relying on executable wrapper
shebang handling. No `bin` files or line endings were changed.

Bundler Audit used the updated Ruby advisory database at commit
`7e90cbd88d767c9281acefbb8854c80e0cad6060`. The baseline audit failed; its output
was retained alongside the clean post-update audit. Results describe known
advisories in that database at verification time, not a permanent guarantee.

## Fresh browser checks with the patched bundle

An isolated headless Chrome context accessed the running Rails application;
no personal browser session was reused.

- Home, Dashboard, History and Settings returned HTTP 200 with English headings.
- All pages remained English with `?lang=zh`, without a language switch, Chinese
  UI text or missing-translation messages.
- All four pages were checked at 1440px and 390px without horizontal overflow;
  screenshots were saved.
- Dashboard showed six sample cards initially and seven after expansion, with
  a Demo preview notice. History showed three samples and a working Expired filter.
- Settings displayed the signed-in account's email.
- Add Purchase, prefilled Edit, Update status and Delete dialogs were submitted;
  each displayed the pending-backend message without purchase writes.
- There were zero JavaScript page errors and zero purchase write requests after login.
- The preview database still contained zero purchases and zero store policies
  after those interactions.

Login was exercised in this browser run. Signup, logout, invalid authentication,
real-record sample replacement and ownership checks are covered by the recorded
Rails suites; they are not claimed as additional manual browser checks here.

## Evidence and reproduction

Full output and exit markers are machine-local under:

```text
/tmp/returnclock-security-fix-20261108/
  audit-before.log
  audit-after.log
  brakeman.log
  importmap-audit.log
  bundle-update.log
  rspec.log
  cucumber.log
  rails-test.log
  rubocop.log
  system-test.log
  server.log
```

Browser screenshots, `browser-results.json` and the script are under the Windows
system temporary directory in `returnclock-security-fix-20261108`. Logs and
databases are not committed; these paths will not exist on teammates' computers.

After following [setup](local-setup.md), choose an unused isolated test database
and run the same checks with the locked bundle:

```sh
bundle check
bundle exec ruby bin/bundler-audit check --update
bundle exec ruby bin/brakeman --no-pager
review_db="return_clock_frontend_review_test_$(date +%Y%m%d%H%M%S)"
# Confirm this name does not already exist before preparing it.
export RAILS_ENV=test
export DATABASE_URL="postgresql:///$review_db"
bundle exec rake db:prepare
bundle exec ruby bin/importmap audit
bundle exec rspec
bundle exec cucumber features --publish-quiet
bundle exec rake test
bundle exec ruby bin/rubocop -f github
bundle exec rake test:system
```

Use `rbenv exec` before commands if required by the local shell. Do not use a
production or shared development database.

## Remaining boundaries

- PR #9 exists; its head was `263a61d` before this local repair. The failed
  `scan_ruby` log was supplied by the user. Successful local checks do not assert
  that GitHub has rerun or passed the repaired delivery; inspect the new SHA's
  actual check results after a separately authorized push.
- The CI workflow remains configured for pull requests and pushes to `main`.
  No check was skipped or weakened to make this repair pass.
- Purchase REST routes remain absent. Real create/edit/status/delete persistence,
  policy transactions, ownership rejection, HTTP 422 recovery and deadline
  recalculation require end-to-end testing after backend integration.
- Physical iOS/Safari and production deployment were not tested. The pinned
  Tabler CDN remains a network dependency.
- This repair does not create another PR, merge into `main`, deploy or authorize
  remote publication. Only the local delivery commit is repackaged unless the
  user separately authorizes updating the published branch.
