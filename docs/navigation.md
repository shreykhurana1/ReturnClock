# Navigation and acceptance handoff

[Quick start](../README.md) · [Architecture](architecture.md)

## Current navigation

| Area | Behavior |
| --- | --- |
| Public landing (`/`) | Centered ReturnClock heading/tagline with Create Account and Sign In. Signed-in visits redirect to Dashboard. |
| Dashboard (`/dashboard`) | Authenticated, read-only cards for upcoming active purchases and all actionable returns/refunds. |
| History (`/history`) | Authenticated, read-only cards for expired active purchases and purchases marked keeping or refunded. |
| Authenticated header | ReturnClock, Dashboard, History, and a profile icon/menu showing the signed-in email, Account Settings, and Sign Out. |
| Add Purchase (`/purchases/new`) | Authenticated form using the user's own store policies. Users without a policy are directed to create one first. |
| Create Store Policy (`/store_policies/new`) | Saves a store name and positive return window in days, then returns to Add Purchase with the new policy selected. |
| Account Settings (`/settings`) | Authenticated placeholder showing the current email and a coming-soon message, with no update functionality. |

Signup and normal login redirect to Dashboard. If an anonymous visitor first
requests a protected page, login preserves Rails' existing return-to-page
behavior. The old `/coming-soon/add-purchase` URL now redirects authenticated
visitors to the real form. Account Settings remains a placeholder. All pages
reuse the shared header. Account changes and Change Password are not implemented.

## Dashboard versus History

Classification uses existing statuses and `Date.current`, with no new database
status or model changes:

| Status | Deadline | Page |
| --- | --- | --- |
| `active` | Today or later | Dashboard |
| `active` | Before today | History |
| `returning`, `shipped_back`, `refund_pending` | Any date, including expired | Dashboard |
| `keeping`, `refunded` | Any date | History |

Dashboard is ordered by `return_by` ascending, then ID for ties. This places
overdue actionable returns/refunds before upcoming deadlines. History is ordered
by deadline descending, then ID descending. A purchase awaiting a refund stays
actionable until marked refunded, even after its original return window ends.

Both controllers start from `Current.user.purchases`, preload store policies,
and accept no mutation actions. Cards display item name, store, price, return
deadline, days remaining (negative after the deadline), and status. Empty pages
show a message, not fabricated purchases. The responsive grid has up to four
columns on large screens, two on medium screens, and one on small screens.

## Integration notes for Ryan and Jordan

- Ryan: Iteration 1 now implements `new`/`create` in `PurchasesController` and
  `StorePoliciesController`. Purchase creation permits only item name, price,
  purchase date, and an owner-scoped policy; the model calculates the deadline.
  Editing, deletion, and status updates remain unimplemented. Add owner-scoped
  authorization tests when extending these controllers.
- The read-only pages live in `DashboardController` and `HistoryController`,
  separate from the creation controllers. Reuse or coordinate changes
  to `shared/_purchase_card.html.erb`, header navigation, and classification.
- Jordan and the Cucumber/UI teammates: further interface decisions remain with
  the assigned teammates. The current layout implements only the stated header,
  card-grid, form, and empty-state requirements. Use the behavior below for
  acceptance scenarios; the existing Cucumber suite includes a first-purchase flow.
- Account updates, change password, reminders, and uploads remain unimplemented.
  Login does not advertise Forgot Password until real delivery is configured.
  Local reset controller tests remain intact; production resets stay disabled.

## Authentication and navigation acceptance criteria

| Situation | Observable outcome |
| --- | --- |
| Signed-out visitor opens the landing page | ReturnClock/tagline and real Create Account/Sign In actions are shown; no authenticated menu appears. |
| Valid signup/login | The user reaches Dashboard and sees their email in the profile menu. |
| Signed-out visitor opens Dashboard/History | They are redirected to Sign In and return to the requested page after successful login. |
| Invalid signup password or confirmation, with JavaScript enabled | Client validation blocks submission, shows a concise field error, and retains entered password values for correction. |
| Server rejects signup, including with JavaScript disabled | Relevant field errors appear, email is retained as submitted, and password fields render blank. No account/session is created. |
| Confirmation mismatch | The message is exactly “Passwords do not match.” |
| Invalid login | The generic credential error appears near the fields, email is retained, and the password field renders blank. |
| Sign out from either page | The active session ends and Sign In is shown. Reusing that session cannot authenticate. |
| Another user's purchases exist | They never appear in either page, including when a `user_id` query parameter is supplied. |
| Refund/return workflow passes its deadline | `returning`, `shipped_back`, and `refund_pending` remain on Dashboard, not History. |
| No matching purchases | A clear empty state appears with no generated sample data. |
| Email delivery is not configured | No Forgot Password link is shown; production direct reset requests remain rejected. |

Use visible field labels/buttons and page headings in Cucumber steps. Native
browser email/required-field validation may also prevent submission. Client
validation supplements Rails' server rules; it does not replace them or store
passwords in flash/session state. The BCrypt byte limit remains enforced but is
not included in the routine password hint.

Review exact spacing and responsive behavior with the UI teammate rather than
using pixel-dependent acceptance assertions. Agree on changes to existing routes,
classification, shared views, and redirect expectations before integrating CRUD.
