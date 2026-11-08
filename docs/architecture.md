# Architecture and team handoff

[Quick start](../README.md) · [Planned navigation](navigation.md)

## Current implementation

- Signup, login, logout, password hashing, email normalization, and validation.
- Read-only Dashboard and History, with authentication and owner-scoped records.
- Database-backed sessions using Rails' built-in authentication system.
- User-owned store policies and purchases, with model validations and foreign keys.
- Authenticated store-policy and purchase creation, including a first-purchase flow.
- Automatic return deadlines, six purchase statuses, and a `days_left` calculation.
- RSpec model/request tests and the retained Minitest suite, both run by CI.
- Heroku configuration for one PostgreSQL database, HTTPS, and Solid services.

Purchase editing/deletion/status updates, further Cucumber stories, final UI
refinements, and email reminders are pending teammate/future work. This repository is prepared for
Heroku; this documentation does not mean an application has been deployed.
Password-reset code is retained and tested locally but disabled in production
until real email delivery is configured.

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
records. Dashboard and History have two-user request authorization coverage. Add the
same coverage when introducing purchase creation/editing/deletion/status-update
endpoints; the read-only tests do not prove the security of future mutation routes.

## Team workflow and responsibilities

| Area | Owner/scope |
| --- | --- |
| Authentication, models/schema, RSpec, README, deployment preparation | Shrey / `shrey/authentication` |
| Purchase workflow | Basic policy/purchase creation implemented; editing/deletion/status updates remain teammate work |
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

Review each feature branch against `main`, commit/push only after approval,
and open a PR from that branch. Teammates should base dependent work on an
unmerged branch only by agreement until it is merged.
