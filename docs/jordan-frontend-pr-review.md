# Frontend and purchase MVP review

This uncommitted integration connects the frontend at `d97c6da` to Shrey's
purchase MVP at `044144c`. Both descend from `9772500`; the backend branch did
not contain the frontend commit. It is applied as local source changes rather
than a Git merge, preserving the current branch and commit history.

Review the purchase and store-policy controllers, routes, purchase form, card
actions, policy pages, header navigation, and History notices together. Upstream
routes and mutation behavior are unchanged, including owner scoping, permitted parameters,
422 validation recovery, status updates and deletion rules. Schema, models,
authentication and the previously patched dependency lockfile are unchanged.

The purchase editor opens in a native dialog from Dashboard/History, with a
full-page fallback for direct visits or JavaScript-free links. Turbo Frames keep
validation and policy setup in the dialog; successful saves refresh the list.
The purchase editor selects a separately saved store policy and offers all
six backend-supported statuses. New policy creation returns with the policy
selected. The former inline-new-policy UI is removed from the purchase form.
Delete uses the upstream confirmation page. Existing demos remain non-persistent
and have no direct status/delete controls; after deleting the last real purchase,
the labeled demos reappear. Each sample now offers Edit as a prefilled new
purchase template, saving an owned copy only on explicit POST. The `new` action
looks up the name in the existing sample helper, copying only name/price/date.
Policy creation retains this template reference. The Store Policies pages reuse
the frontend styles.

Upstream purchase/policy request tests and Cucumber stories are included, along
with updated frontend form/route assertions. Read [the current verification
record](jordan-frontend-verification.md) for results; historical preview-only
testing does not establish the correctness of this integration.

No commit, push, PR mutation, main-branch merge or deployment has been performed.
