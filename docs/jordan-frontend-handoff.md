# Iteration 1 frontend handoff

This document describes the English-only frontend on
`shreykhurana1/ReturnClock`, branch `iteration1-frontend`.
The integration base is `97725000d228032afd108942b5055e531ec91220`.
The frontend is represented by one `findjordanwoods` commit after that base.
See [verification results](jordan-frontend-verification.md) for the application
revision checked and [review notes](jordan-frontend-pr-review.md) for review scope.

## Current application behavior

| Page | Implemented behavior |
| --- | --- |
| `/` | Public landing page with the existing Sign In and Create Account flow; signed-in visitors follow the existing Dashboard redirect. |
| `/dashboard` | Purchase cards and totals; the first six records appear initially and the rest expand through a details control. Real records retain the controller's `return_by, id` ordering. |
| `/history` | Separate history page with total, Refunded, Keeping and Expired counts, plus client-side status filters. |
| `/settings` | Current user's read-only email and account information. Password changes, reminders and personalization are labeled unavailable. Sign Out uses the existing session endpoint. |
| `/coming-soon/add-purchase` | Safe fallback destination for the Add Purchase link when JavaScript is unavailable; it does not save purchases. |

The existing controllers scope real records through `Current.user.purchases`.
Dashboard includes active purchases due today or later, and existing `returning`,
`shipped_back` and `refund_pending` records even after their deadlines.
History contains `keeping`, `refunded`, and active purchases past their deadline.
Completed or expired cards omit the days-remaining field. Amount saved remains
unavailable rather than showing an invented savings total.

The UI is English-only. There is no language switch, Chinese locale, preview
language setting or `.ZH` template. A former `?lang=zh` parameter is ignored.
User-entered product and store names are displayed as entered.
Code comments are English; this is independent of the language of user data.

## Sample cards for accounts without purchases

If the account has no persisted purchases, the main lists display unsaved
`Purchase` and `StorePolicy` objects built by `sample_purchases`:

- Dashboard: seven active samples, with six initially visible and one expandable.
- History: three samples covering Refunded, Keeping and Expired.
- Dates are relative to `Date.current`; cards and totals have a Demo preview notice.
- Neither sample purchases nor sample policies are written to PostgreSQL.
- Once the account has any real purchase, samples disappear from both pages,
  including a page whose own real-record list is empty.

Fresh local installations have no shared default login. Prepare the local
database and register through Create Account. The repository does not seed a
demo account or distribute the local preview database. See [setup](local-setup.md).

## Purchase interactions and backend boundary

Add Purchase opens an editor, Edit opens a prefilled editor, and More actions
opens status and deletion interactions. Current submissions only display
"Waiting for backend integration" and do not send purchase write requests,
change the visible records, or claim a successful save. No localStorage
purchase persistence is used.

`purchase_preview_enabled?` is shared by the layout and card template. It checks
whether `new_purchase_path`, `edit_purchase_path` and `purchase_path` all exist.
When all three exist, preview dialogs stop rendering and unsaved sample cards
hide Edit/Status/Delete actions. Persisted cards can use real REST actions.
These helper checks support template integration; they do not prove that
backend validation, authorization or persistence is implemented.
Partial route integration must be tested explicitly before enabling writes.

## REST contract for Sophia and Ryan

None of the following purchase routes currently exists in `config/routes.rb`.
The backend team must implement the routes, actions, validation and ownership
checks together. The prepared templates can be reused.

| Method | Path | Action | Prepared frontend |
| --- | --- | --- | --- |
| GET | `/purchases/new` | new | `app/views/purchases/new.html.erb` |
| POST | `/purchases` | create | `app/views/purchases/_form.html.erb` |
| GET | `/purchases/:id/edit` | edit | `app/views/purchases/edit.html.erb` |
| PATCH | `/purchases/:id` | update | Edit form and `app/views/shared/_purchase_actions.html.erb` |
| DELETE | `/purchases/:id` | destroy | Shared card action with Turbo confirmation |

- `new`: provide `@purchase = Current.user.purchases.build`, normally with
  `purchase_date: Date.current` and `status: "active"`.
- `edit`: load `@purchase` through `Current.user.purchases.find(params[:id])`.
- The templates read policies through `Current.user.store_policies.order(:store_name)`;
  no separate `@store_policies` variable is required.
- Failed create/update must retain `@purchase.errors` and form parameters and
  re-render the appropriate template with HTTP 422. Preserve new-policy input.
- Update must accept a status-only request. Successful mutations should use the
  team's agreed redirect, normally HTTP 303 for Turbo-compatible navigation.
- The card is rendered as `shared/purchase_card` with a `purchase` local; the
  action partial also accepts `status_names`.

## Fields and parameters

Purchase form fields are `item_name`, `price`, `purchase_date`, `store_policy_id`
and `status`. The existing model derives `return_by` from the purchase date and
policy's `window_days`; cards read `days_left`. The frontend does not submit
`user_id` or a client-supplied `return_by`.

Existing-policy mode sends:

```text
purchase[item_name]
purchase[price]
purchase[purchase_date]
purchase[store_policy_id]
purchase[status]
```

New-policy mode sends:

```text
purchase[item_name]
purchase[price]
purchase[purchase_date]
purchase[status]
store_policy[store_name]
store_policy[window_days]
```

`store_name` and positive integer `window_days` belong to a policy owned by the
current user. `rc_store_policy_controller.js` disables hidden mode inputs so
both policy alternatives are not submitted together. The backend must validate
and associate the selected or newly created policy under the current user;
use a transaction to avoid leaving an orphan policy after a failed purchase.
This new-policy persistence is not implemented by the frontend.

The model retains its six statuses: `active`, `keeping`, `returning`,
`shipped_back`, `refund_pending`, `refunded`. Current manual choices are Active,
Keeping and Refunded. Real edit forms preserve an existing legacy intermediate
status as a disabled option; updates must preserve existing fields if omitted.
Expired is a presentation category for active records with `days_left < 0`,
not a value to write into `status`.

## Integration checks still required

After backend integration, verify creation with both policy modes, editing,
status-only updates, delete confirmation/cancellation, HTTP 422 form recovery,
transaction rollback, cross-user purchase and policy rejection, deadline
recalculation, and Dashboard/History classification.

The static helper tests that simulate CRUD route availability do not replace
these end-to-end checks. Existing authentication, models, controllers, routes,
schema and deployment configuration are unchanged from the integration base.
`Gemfile.lock` includes conservative security-patch updates for Rails 8.1.4.1,
Nokogiri 1.19.7, Rack 3.2.8, rails-html-sanitizer 1.7.2, Loofah 2.25.3 and
Addressable 2.9.2. `Gemfile` constraints, lockfile platforms and CI checks are unchanged.
Tabler 1.6.1 loads from a pinned CDN stylesheet alongside local `rc-*` styles;
network availability affects the CDN resource.
