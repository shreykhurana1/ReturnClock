# Iteration 1 frontend review notes

## Branch and delivery status

- Repository: `shreykhurana1/ReturnClock`.
- Review branch: `iteration1-frontend`.
- Integration base: `97725000d228032afd108942b5055e531ec91220`.
- One frontend commit follows the base, authored and committed by `findjordanwoods`
  with subject `Iteration 1 frontend`.
- Application source and test files retain the English-only frontend; the
  delivery also includes the security-patched lockfile described below.
  The single frontend delivery commit also includes the current documentation.
  Use `git log -1` to identify that delivery commit; its SHA changes when documentation is amended.
- [PR #9](https://github.com/shreykhurana1/ReturnClock/pull/9) exists for this branch.
  The user supplied its failing `scan_ruby` log. This local security repair does
  not merge into `main`, deploy, or establish a successful remote CI rerun.

Check the live base and branch history again before merging:

```sh
git fetch origin
git log --oneline origin/main..iteration1-frontend
git diff --stat origin/main...iteration1-frontend
```

If the upstream base advances, review and integrate its changes without
replacing teammates' work. Pushing a branch does not authorize a PR or merge.

## Scope for reviewers

The application changes cover Home, Dashboard, History, Account Settings,
authentication form presentation, purchase forms and preview dialogs, sample
cards, styles, icons, and frontend tests. The UI and code comments are English.
There is no language switch, Chinese locale or language preview environment flag.

Compared with the integration base, controllers, authentication concerns,
models, routes, database configuration, migrations/schema, `Gemfile` constraints
and deployment files are unchanged. `Gemfile.lock` deliberately updates only
security-patch releases within the existing version lines: Rails 8.1.4.1 and its
matching components, Nokogiri 1.19.7, Rack 3.2.8, rails-html-sanitizer 1.7.2,
Loofah 2.25.3 and Addressable 2.9.2. No audit exclusions or weakened CI checks
were added. The existing lockfile platform list is preserved.

Review these shared areas:

| Files | Review focus |
| --- | --- |
| `app/helpers/application_helper.rb` | Unsaved sample generation, existing status compatibility, English messages and `purchase_preview_enabled?`. |
| `app/views/layouts/application.html.erb` | English document language, icons, pinned Tabler CSS, and conditional preview rendering. |
| `app/views/shared/_purchase_card.html.erb`, `_purchase_actions.html.erb` | Data escaping, state labels, conditional days, persisted-record REST actions and unsaved-sample protection. |
| `app/views/purchases/`, `app/views/shared/_purchase_preview.html.erb` | Shared fields, policy modes, errors, standard forms versus no-write preview forms. |
| `app/javascript/controllers/rc_*` | Client-side filtering, disabled policy fields and preview dialog behavior. |
| `app/views/sessions/`, `sign_ups/`, `passwords/`, and `signup_validation_controller.js` | English labels and error presentation while preserving authentication behavior. |
| `features/authentication.feature` and frontend specs | Signup/login navigation, sample behavior, route-transition protection and form contracts. |

No purchase REST endpoints have been added. Add/Edit/Status/Delete currently
remain previews. See the [handoff contract](jordan-frontend-handoff.md) for
routes, fields, variables and backend ownership requirements.

## Sample and future-CRUD protection

Accounts with no purchases see seven Dashboard samples and three History
samples. Demo cards and totals are labeled and not persisted. Any real purchase
hides samples on both pages. Savings are not fabricated.

The layout and card use the same preview-availability helper. When all three
standard purchase path helpers exist, preview dialogs and unsaved-sample
mutation controls disappear. Persisted records retain their REST integration.
The helper/view regression tests simulate this transition; real CRUD requires
separate integration and authorization tests after the backend is implemented.

## Verification and remaining gates

The current local results and their exact application revision are recorded in
[verification results](jordan-frontend-verification.md). They include full
RSpec, Cucumber, Rails Test and RuboCop runs, with browser checks identified
separately. Local results do not establish a successful GitHub Actions run.

The existing CI workflow runs for pull requests and pushes to `main`; pushing
only this feature branch is not a configured push trigger. Check actual CI
results during a separately authorized PR review. The workflow is unchanged. Local security scans have been run for this patch;
their results and the limits of local verification are recorded separately.

Before integration:

1. Recheck the current upstream base and review all changed shared files.
2. Reproduce the documented suites in an isolated local test database or CI.
3. Check signup, login, logout, English-only pages, demo labeling, sample
   non-persistence, real-record replacement and narrow-screen layout.
4. After implementing purchase endpoints, verify both policy modes, invalid
   input recovery, status-only updates, deletion, ownership checks, transactions
   and deadline-based classification.
5. Obtain separate approval before creating a PR, merging or deploying.
