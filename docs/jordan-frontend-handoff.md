# Frontend and purchase MVP integration

Local working tree: `iteration1-frontend` in the designated submit2 checkout.
The original frontend is `d97c6da`; purchase integration and dialogs were committed
and pushed as `2207a90`. The current pending merge incorporates latest main
`ae1b4d0`. All conflicts are resolved locally; the merge commit/push are pending.
Gemfile/lockfile match main. Frontend behavior below is preserved; see the latest
[verification](jordan-frontend-verification.md) for actual post-resolution checks.

## Current behavior

The original English frontend, Dashboard/History classification, six-card
expansion, sample notices, authentication pages, and account settings remain.
Shrey's purchase and store-policy controllers provide the CRUD implementation.
The local follow-up adds allowlisted demo-template prefilling in `new` and
retains the template across separate policy creation; routes and mutation
validation/authorization are unchanged.
Models, schema, authentication, dependency lockfile and CI are unchanged.

- Add Purchase and card Edit open a modal using the existing new/edit routes.
  Demo Edit uses the same modal with its prefilled template. The modal shows
  one heading for Add Purchase, Edit Purchase or Edit Sample Purchase; full-page
  breadcrumbs and repeated headings are hidden inside it. Direct URL visits
  and JavaScript-free links retain the full editor pages. Cancel, Close, backdrop
  and Escape dismiss the modal; HTTP 422 errors retain input inside it. Saving
  refreshes the existing Dashboard/History destination. Store-policy creation
  stays inside the modal. The old coming-soon URL redirects to `/purchases/new`.
- Create a store policy separately, then select it in the purchase form.
  Policy creation redirects back with that owned policy selected.
  Inline policy creation is no longer offered by the purchase form.
- Purchase fields are `item_name`, `price`, `purchase_date`, `store_policy_id`;
  updates may also submit `status`. The backend ignores submitted owners/deadlines
  and applies the existing model's deadline calculation.
- The More actions status menu offers Active, Keeping and Refunded. An existing
  workflow status remains as its current selection to avoid accidental changes;
  the other workflow states are not offered. Expired is derived from an active
  purchase's deadline, not a writable status. The full editor retains all six
  backend-supported statuses.
  Status-only PATCH requests work. Keeping/refunded and expired active purchases
  return to History after update; other states return to Dashboard.
- Cards link to Edit and a separate Delete Purchase confirmation. GET never
  deletes; Cancel returns to Edit; confirmation submits DELETE.
- Store Policies in the header opens owner-scoped creation/editing/deletion.
  Used policies cannot be deleted. Policy edits preserve existing deadlines;
  a new purchase or a changed purchase date/policy uses the current window.
- Failed forms render HTTP 422 with entered values and escaped errors.
- Empty accounts retain labeled, unsaved samples. Each sample now has Edit,
  opening a prefilled new-purchase form with the demo name, price and purchase
  date. GET does not create records. Saving explicitly creates an owned real
  purchase using the selected owned policy; it starts active under the existing
  backend rules. Its derived deadline can place it in History. No status/delete
  mutation menu is offered on unsaved samples. Samples reappear after the last
  real purchase is deleted. Policy setup preserves the selected demo template.
- Real CRUD routes disable the former interactive preview dialogs.

## Integration decisions

Overlapping forms, cards, header and History keep the existing frontend markup
with the upstream actions connected. Policy and confirmation pages reuse the
existing editor/card styles. Our patched `Gemfile.lock` and setup/deployment
documentation are retained; Shrey's unrelated documentation deletion is omitted.
The upstream request/acceptance tests are included. Card selectors in acceptance
steps use exact headings to ignore decorative badges; request assertions separate
persisted records from demos. Neither change weakens mutation/ownership checks.

See [verification](jordan-frontend-verification.md) for actual results and limits.
Commit, push, PR changes, merge and deployment require separate authorization.
