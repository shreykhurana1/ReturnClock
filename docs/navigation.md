# Navigation and acceptance handoff

See [setup](local-setup.md), [architecture](architecture.md), and the current
[frontend/purchase integration contract](jordan-frontend-handoff.md).

| Area | Current behavior |
| --- | --- |
| `/` | Public landing; signed-in visitors redirect to Dashboard. |
| `/dashboard` | Owned active purchases due today or later, plus returning/shipped_back/refund_pending records regardless of deadline. Six initially visible; more expand. |
| `/history` | Owned keeping/refunded purchases and active purchases past their deadline; client-side status filters. |
| Header | Dashboard, History, Store Policies, account settings and Sign Out. Add Purchase is in Dashboard content. |
| `/purchases/new` | Real purchase form; create a store policy first, then select it. |
| `/purchases/:id/edit` | Owner-scoped editing of details, policy and all six statuses. |
| `/purchases/:id/confirm_delete` | Confirmation and Cancel; only DELETE removes a purchase. |
| `/store_policies` | Owner-scoped list, creation, editing and deletion of unused policies. |
| `/coming-soon/add-purchase` | Redirects to the real purchase editor. |
| `/settings` | Read-only account email; changes and reminders remain unavailable. |

Signup/login normally redirects to Dashboard. Protected requests preserve the
requested destination through login. Other users' purchases and policies are
never available through submitted IDs. Account changes and email reminders are
not implemented; production password reset remains disabled pending email setup.

Dashboard sorts by deadline/ID ascending; History sorts descending. Expired
active, keeping and refunded cards omit days remaining. Empty accounts display
clearly labeled unsaved samples with Edit links to prefilled new-purchase forms; real records replace
the samples, which return after the last real purchase is deleted.

The acceptance suites cover authentication, policy-to-purchase creation, editing,
status transitions, deletion confirmation/cancel and saved deadline behavior.
Use visible labels and exact card headings, independent of decorative icons.
Actual verification results are recorded in
[jordan-frontend-verification.md](jordan-frontend-verification.md).
