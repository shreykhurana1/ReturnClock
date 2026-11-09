# ReturnClock — Cucumber Draft (MVP)

Each feature below becomes one `.feature` file under `features/`. Every scenario runs on Capybara's default `rack_test` driver (no JavaScript).

## Ground rules

- **Dates are frozen.** Scenarios that depend on "today" start with `Given today is <date>`, which uses Rails `travel_to`; an `After` hook travels back. Everything runs in UTC.
- **Logged-in user.** `Given I am logged in as "someone@example.com"` creates the user (password "password123") and logs in through the real form.
- **Top bar** on every logged-in page: "Purchases", "History", "Settings", and a "Log out" button.
- **No JavaScript.** Actions that change data (log out, delete, status changes, save store) are buttons (`button_to`), so they work without JS.

**Statuses and where they show up:**

```
active           open, no decision yet          Purchases page
returning        decided to return, not sent    Purchases page
awaiting_refund  sent back, money not arrived   Purchases page  (shown as "Returned, awaiting refund")
keeping          decided to keep                History page
refunded         money arrived                  History page
expired          deadline passed while active   History page
                 or returning
```

### Adding or editing a purchase

```
required: item_name
optional: store, price, purchase date (prefilled with today), return window, return by

return_by is resolved in this order:
    1. "Return by" filled in                → use it (window = return_by - purchase_date)
    2. purchase date + "Return window"      → purchase_date + window
    3. purchase date + a saved store policy → purchase_date + that policy's window
    4. none of the above                    → "Add a return-by date, or a purchase date and return window"

errors: blank item name, price < 0, window < 0,
        return_by before purchase_date ("Return by can't be before the purchase date")

return_by < today when added   → saved as expired, with the notice
                                 'The return-by date has passed, so "Boots" was logged as expired.'
expired purchase edited so return_by >= today → back to active
```

### Expiry

```
Purchase.expire_overdue!(today):
    status active or returning AND return_by < today → expired
Called by the reminder job and by the Purchases and History pages before rendering.
Due today (return_by == today) is not expired yet.
```

### Saved store policies

```
One policy per store per user: a store name and a window (store names match case-insensitively).

After a purchase with a store and a window is saved, and that store has no saved policy:
    banner: Save store "Zara" with a 30 day return window? [Save store] [No thanks]
    [Save store] → saves the policy, shows "Saved: Zara · 30 day return"
    [No thanks]  → plain link back to the purchases page; nothing saved

A purchase is linked to a policy (store_policy_id) when its store and window match one.
```

### Purchases page

```
Sorted by days left, soonest first; awaiting-refund cards go last.

days_left = return_by - today
    <= 3 → "urgent" (red)     <= 7 → "soon" (yellow)     otherwise → "safe" (green)
awaiting_refund → "awaiting" (blue), no countdown, shows "Returned Oct 15, 2026, awaiting refund"

Money at risk = sum of price for active and returning purchases (no price counts as $0).
```

Cucumber checks the CSS class (e.g. `.card.urgent`), not the actual color.

### History page

```
Sorted by return-by date, newest first (ties: item name A–Z).
Each entry: item name, store and price if entered, status label, Status dropdown + [Update].
    keeping  → "Kept"                       gray
    refunded → "Refunded on Oct 15, 2026"   green
    expired  → "Expired on Oct 31, 2026"    red
```

### Schema

```
users:          Devise columns, reminder_days_before integer NOT NULL DEFAULT 2

purchases:      user_id FK NOT NULL, store_policy_id FK NULL,
                item_name string NOT NULL, store_name string NULL,
                price decimal(10,2) NULL, purchase_date date NULL,
                return_window_days integer NULL, return_by date NOT NULL,
                status string NOT NULL DEFAULT "active",
                returned_at date NULL, refunded_at date NULL, reminded_at datetime NULL

store_policies: user_id FK NOT NULL, store_name string NOT NULL, window_days integer NOT NULL
                UNIQUE(user_id, LOWER(store_name))
```

### Future plans (not in the MVP)

Live date-field syncing, an autosaving edit form, store suggestions while typing, several policies per store, editing saved stores, password reset and change, a "1 day left" alert with a day-before email, per-user time zones, and urgency colors that follow the reminder setting.


---

## Feature 1: Account sign up, log in, log out
File: `features/authentication.feature`

```gherkin
Feature: Account access
  As a shopper
  I want my own private account
  So that only I can see my purchases and return deadlines

  Scenario: Sign up with an email and password
    Given I am on the sign up page
    When I sign up with email "someone@example.com" and password "password123"
    Then I should be on the purchases page
    And I should see "Welcome to ReturnClock"

  Scenario: Cannot sign up with an email that is already taken
    Given a user exists with email "someone@example.com" and password "password123"
    And I am on the sign up page
    When I sign up with email "someone@example.com" and password "password123"
    Then I should see "Email has already been taken"

  Scenario: Cannot sign up when passwords do not match
    Given I am on the sign up page
    When I fill in "Email" with "someone@example.com"
    And I fill in "Password" with "password123"
    And I fill in "Password confirmation" with "different"
    And I press "Sign up"
    Then I should see "Password confirmation doesn't match"

  Scenario: Log in with correct credentials
    Given a user exists with email "someone@example.com" and password "password123"
    When I log in with email "someone@example.com" and password "password123"
    Then I should be on the purchases page

  Scenario: Log in with the wrong password
    Given a user exists with email "someone@example.com" and password "password123"
    When I log in with email "someone@example.com" and password "wrong"
    Then I should see "Invalid email or password"
    And I should be on the login page

  Scenario: Log out
    Given I am logged in as "someone@example.com"
    When I press "Log out"
    Then I should be on the login page

  Scenario: Logged-out visitors are sent to the login page
    Given I am not logged in
    When I go to the purchases page
    Then I should be on the login page

  Scenario: Users only see their own purchases
    Given "bob@example.com" has a purchase "Bob's Lamp" returnable by 2026-12-01
    And I am logged in as "someone@example.com"
    When I go to the purchases page
    Then I should not see "Bob's Lamp"
```


---

## Feature 2: Add a purchase with as little or as much detail as I want
File: `features/add_purchase.feature`

```gherkin
Feature: Add a purchase
  As a shopper
  I want to log a purchase with only the details I have handy
  So that tracking a return never feels like a chore

  Background:
    Given today is 2026-10-01
    And I am logged in as "someone@example.com"
    And I am on the new purchase page

  Scenario: Minimal — just an item name and a return-by date
    When I fill in "Item name" with "Lamp"
    And I fill in "Purchase date" with ""
    And I fill in "Return by" with "2026-12-01"
    And I press "Save purchase"
    Then I should be on the purchases page
    And the "Lamp" card should show return date "Dec 1, 2026"

  Scenario: Minimal — an item name, purchase date, and return window
    When I fill in "Item name" with "Lamp"
    And I fill in "Purchase date" with "2026-09-20"
    And I fill in "Return window (days)" with "30"
    And I press "Save purchase"
    Then the "Lamp" card should show return date "Oct 20, 2026"

  Scenario: Full detail
    When I fill in "Item name" with "Jacket"
    And I fill in "Store" with "Target"
    And I fill in "Price" with "60.00"
    And I fill in "Purchase date" with "2026-10-01"
    And I fill in "Return window (days)" with "90"
    And I press "Save purchase"
    Then the "Jacket" card should show store "Target"
    And the "Jacket" card should show "$60.00"
    And the "Jacket" card should show return date "Dec 30, 2026"

  Scenario: If the window and return-by disagree, return-by wins
    When I fill in "Item name" with "Lamp"
    And I fill in "Purchase date" with "2026-10-01"
    And I fill in "Return window (days)" with "30"
    And I fill in "Return by" with "2026-11-15"
    And I press "Save purchase"
    Then the "Lamp" card should show return date "Nov 15, 2026"
    When I go to the edit page for "Lamp"
    Then the "Return window (days)" field should contain "45"

  Scenario: A purchase with a past deadline is logged as expired
    When I fill in "Item name" with "Boots"
    And I fill in "Purchase date" with "2026-08-01"
    And I fill in "Return by" with "2026-08-31"
    And I press "Save purchase"
    Then I should see 'The return-by date has passed, so "Boots" was logged as expired.'
    And I should not see a purchase card for "Boots"
    And "Boots" should have status "expired"

  Scenario Outline: Missing or invalid details are rejected
    When I fill in "Item name" with "<item>"
    And I fill in "Price" with "<price>"
    And I fill in "Purchase date" with "<purchase_date>"
    And I fill in "Return window (days)" with "<window>"
    And I fill in "Return by" with "<return_by>"
    And I press "Save purchase"
    Then I should see "<error>"

    Examples:
      | item | price | purchase_date | window | return_by  | error                                                       |
      | Lamp |       |               |        |            | Add a return-by date, or a purchase date and return window |
      | Lamp |       | 2026-10-01    |        |            | Add a return-by date, or a purchase date and return window |
      |      |       | 2026-10-01    | 30     |            | Item name can't be blank                                    |
      | Lamp |       | 2026-10-01    |        | 2026-09-25 | Return by can't be before the purchase date                 |
      | Lamp | -5    | 2026-10-01    | 30     |            | Price must be greater than or equal to 0                    |
      | Lamp |       | 2026-10-01    | -3     |            | Return window can't be negative                             |
```


---

## Feature 3: Saved store return policies
File: `features/store_policies.feature`

```gherkin
Feature: Save a store's return policy
  As a shopper
  I want ReturnClock to remember each store's return window
  So that next time I only have to type the store name

  Background:
    Given today is 2026-10-01
    And I am logged in as "someone@example.com"

  Scenario: Save a new store after adding a purchase
    When I add a purchase "Dress" from store "Zara" with a 30 day window
    Then I should see "Save store \"Zara\" with a 30 day return window?"
    When I press "Save store"
    Then I should see "Saved: Zara · 30 day return"
    And I should have a saved store "Zara" with a 30 day return window
    And "Dress" should be linked to the saved store "Zara · 30 day return"

  Scenario: A saved store fills in the window when I leave it blank
    Given I have a saved store "Zara" with a 30 day return window
    And I am on the new purchase page
    When I fill in "Item name" with "Skirt"
    And I fill in "Store" with "Zara"
    And I press "Save purchase"
    Then the "Skirt" card should show return date "Oct 31, 2026"
    And "Skirt" should be linked to the saved store "Zara · 30 day return"

  Scenario: No prompt when the store is already saved
    Given I have a saved store "Zara" with a 30 day return window
    When I add a purchase "Dress" from store "Zara" with a 30 day window
    Then I should not see the save-store banner
```


---

## Feature 4: Purchases dashboard
File: `features/purchases_dashboard.feature`

*Each card shows: item name, return-by date, days left, an "Edit" button, and status controls (Feature 6). Store and price show only if entered.*

```gherkin
Feature: Purchases dashboard
  As a shopper
  I want to see everything I can still return, soonest deadline first
  So that I return things before it is too late

  Background:
    Given today is 2026-10-15
    And I am logged in as "someone@example.com"

  Scenario: Cards are sorted by days left, soonest first
    Given I have the following purchases:
      | item       | return_by  |
      | Jacket     | 2026-12-30 |
      | Dress      | 2026-10-31 |
      | Headphones | 2026-10-16 |
    When I go to the purchases page
    Then I should see "Headphones" before "Dress"
    And I should see "Dress" before "Jacket"

  Scenario: A card shows the details I entered
    Given I have the following purchases:
      | item   | store  | price | purchase_date | return_by  |
      | Jacket | Target | 60.00 | 2026-10-01    | 2026-12-30 |
      | Lamp   |        |       |               | 2026-12-01 |
    When I go to the purchases page
    Then the "Jacket" card should show store "Target"
    And the "Jacket" card should show return date "Dec 30, 2026"
    And the "Jacket" card should show "76 days left"
    And the "Jacket" card should show "$60.00"
    And the "Lamp" card should show "47 days left"
    And the "Lamp" card should not show a price

  Scenario Outline: Cards are color coded by urgency
    Given I have the following purchases:
      | item | return_by   |
      | Lamp | <return_by> |
    When I go to the purchases page
    Then the "Lamp" card should show "<days_text>"
    And the "Lamp" card should be marked "<urgency>"

    Examples:
      | return_by  | days_text    | urgency |
      | 2026-10-15 | Due today    | urgent  |
      | 2026-10-18 | 3 days left  | urgent  |
      | 2026-10-19 | 4 days left  | soon    |
      | 2026-10-22 | 7 days left  | soon    |
      | 2026-10-23 | 8 days left  | safe    |

  Scenario: Awaiting-refund cards get their own color and no countdown
    Given I have the following purchases:
      | item   | return_by  | status          |
      | Jacket | 2026-12-30 | active          |
      | Shoes  | 2026-10-16 | awaiting_refund |
    When I go to the purchases page
    Then the "Shoes" card should be marked "awaiting"
    And the "Shoes" card should not show "1 day left"
    And the "Shoes" card should show status "Returned, awaiting refund"
    And I should see "Jacket" before "Shoes"

  Scenario: Money at risk counts only priced items I can still return
    Given I have the following purchases:
      | item   | price | return_by  | status    |
      | Jacket | 60.00 | 2026-12-30 | active    |
      | Dress  | 25.00 | 2026-10-31 | returning |
      | Lamp   |       | 2026-12-01 | active    |
      | Scarf  | 20.00 | 2026-10-31 | keeping   |
      | Shoes  | 50.00 | 2026-10-31 | refunded  |
    When I go to the purchases page
    Then I should see "Money at risk: $85.00"

  Scenario: Empty dashboard
    When I go to the purchases page
    Then I should see "Money at risk: $0.00"
    And I should see "No purchases yet"
    And I should see "+ Add Purchase"
```


---

## Feature 5: Edit or delete a purchase
File: `features/edit_purchase.feature`

```gherkin
Feature: Edit a purchase
  As a shopper
  I want to fix or fill in details later
  So that I can start minimal and add more when I have the receipt

  Background:
    Given today is 2026-10-15
    And I am logged in as "someone@example.com"
    And I have the following purchases:
      | item   | store  | price | purchase_date | return_by  |
      | Jacket | Target | 60.00 | 2026-10-01    | 2026-12-30 |

  Scenario: Edit a purchase from its card
    Given I am on the purchases page
    When I press "Edit" on the "Jacket" card
    And I fill in "Item name" with "Winter Jacket"
    And I fill in "Price" with "55.00"
    And I fill in "Return by" with "2026-11-30"
    And I press "Save purchase"
    Then I should be on the purchases page
    And the "Winter Jacket" card should show "$55.00"
    And the "Winter Jacket" card should show return date "Nov 30, 2026"

  Scenario: Extending the deadline brings an expired purchase back
    Given I have the following purchases:
      | item  | return_by  | status  |
      | Mixer | 2026-10-10 | expired |
    And I am on the edit page for "Mixer"
    When I fill in "Return by" with "2026-10-25"
    And I press "Save purchase"
    Then I should see a purchase card for "Mixer"
    And "Mixer" should have status "active"

  Scenario: Item name can't be removed
    Given I am on the edit page for "Jacket"
    When I fill in "Item name" with ""
    And I press "Save purchase"
    Then I should see "Item name can't be blank"

  Scenario: Delete a purchase logged by mistake
    Given I am on the edit page for "Jacket"
    When I press "Delete purchase"
    Then I should be on the purchases page
    And I should not see "Jacket"
```


---

## Feature 6: Track a return through to refund, or let it expire
File: `features/return_tracking.feature`

```
Quick buttons on each card:   active → [Keep it] [Return it]
                              returning → [Sent it back]
                              awaiting_refund → [Refund received]
Status dropdown + [Update] on every card and History entry (all 6 statuses).

entering awaiting_refund → returned_at = today
entering refunded        → refunded_at = today
active or returning chosen when return_by < today → rejected:
    "The return-by date has passed. Edit the return-by date to reopen this purchase."
```

```gherkin
Feature: Track a return
  As a shopper
  I want changing a purchase's status to take one click
  So that keeping my returns up to date is effortless

  Background:
    Given today is 2026-10-15
    And I am logged in as "someone@example.com"
    And I have the following purchases:
      | item   | price | return_by  |
      | Jacket | 60.00 | 2026-12-30 |

  Scenario Outline: Quick buttons move a purchase to its next status
    Given "Jacket" has status "<from>"
    And I am on the purchases page
    When I press "<button>" on the "Jacket" card
    Then "Jacket" should have status "<to>"

    Examples:
      | from            | button          | to              |
      | active          | Keep it         | keeping         |
      | active          | Return it       | returning       |
      | returning       | Sent it back    | awaiting_refund |
      | awaiting_refund | Refund received | refunded        |

  Scenario: Keeping an item moves it to History
    Given I am on the purchases page
    When I press "Keep it" on the "Jacket" card
    Then I should not see "Jacket"
    And I should see "Money at risk: $0.00"
    When I follow "History"
    Then the "Jacket" history entry should show status "Kept"

  Scenario: Full return walkthrough with quick buttons
    Given I am on the purchases page
    When I press "Return it" on the "Jacket" card
    And I press "Sent it back" on the "Jacket" card
    Then the "Jacket" card should show status "Returned Oct 15, 2026, awaiting refund"
    When I press "Refund received" on the "Jacket" card
    Then I should not see "Jacket"
    And I should see "Money at risk: $0.00"
    When I follow "History"
    Then the "Jacket" history entry should show status "Refunded on Oct 15, 2026"

  Scenario: Skip straight to refunded with the dropdown (in-store return)
    Given I am on the purchases page
    When I select "Refunded" from the "Jacket" card's "Status" dropdown
    And I press "Update" on the "Jacket" card
    Then "Jacket" should have status "refunded"

  Scenario: Undo a mistake from the History page
    Given "Jacket" has status "keeping"
    And I am on the history page
    When I select "Active" from the "Jacket" history entry's "Status" dropdown
    And I press "Update" on the "Jacket" history entry
    Then I should be on the history page
    And I should not see "Jacket"
    When I follow "Purchases"
    Then I should see a purchase card for "Jacket"

  Scenario: Can't reopen a purchase whose deadline has passed by status alone
    Given I have the following purchases:
      | item  | return_by  | status  |
      | Mixer | 2026-10-10 | expired |
    And I am on the history page
    When I select "Active" from the "Mixer" history entry's "Status" dropdown
    And I press "Update" on the "Mixer" history entry
    Then I should see "The return-by date has passed. Edit the return-by date to reopen this purchase."
    And "Mixer" should have status "expired"

  Scenario Outline: Open purchases expire the day after the deadline
    Given I have the following purchases:
      | item  | price | return_by  | status   |
      | Dress | 45.00 | 2026-10-31 | <status> |
    And today is <today>
    When I go to the purchases page
    Then "Dress" should have status "<result>"

    Examples:
      | status          | today      | result          |
      | active          | 2026-10-31 | active          |
      | active          | 2026-11-01 | expired         |
      | returning       | 2026-11-01 | expired         |
      | keeping         | 2026-11-01 | keeping         |
      | awaiting_refund | 2026-11-01 | awaiting_refund |
```


---

## Feature 7: History page
File: `features/history.feature`

```gherkin
Feature: Purchase history
  As a shopper
  I want a separate page of purchases that are finished
  So that my main dashboard only shows what still needs action

  Background:
    Given today is 2026-12-01
    And I am logged in as "someone@example.com"
    And I have the following purchases:
      | item   | return_by  | status          |
      | Scarf  | 2026-10-31 | keeping         |
      | Shoes  | 2026-10-31 | refunded        |
      | Dress  | 2026-10-31 | expired         |
      | Jacket | 2026-12-30 | active          |
      | Boots  | 2026-12-20 | awaiting_refund |

  Scenario: History lists only finished purchases
    Given I am on the purchases page
    When I follow "History"
    Then I should see "Scarf"
    And I should see "Shoes"
    And I should see "Dress"
    And I should not see "Jacket"
    And I should not see "Boots"

  Scenario: Overdue purchases expire when I open History
    Given today is 2026-12-31
    When I go to the history page
    Then "Jacket" should have status "expired"
    And the "Jacket" history entry should show status "Expired on Dec 30, 2026"
    And "Boots" should have status "awaiting_refund"
    And I should not see "Boots"

  Scenario Outline: History entries are color coded by outcome
    When I go to the history page
    Then the "<item>" history entry should be marked "<outcome>"
    And the "<item>" history entry should show status "<label>"

    Examples:
      | item  | outcome  | label                   |
      | Scarf | kept     | Kept                    |
      | Shoes | refunded | Refunded                |
      | Dress | expired  | Expired on Oct 31, 2026 |

  Scenario: Newest return-by date first, ties by name
    Given I have the following purchases:
      | item | store | price | return_by  | status   |
      | Hat  | Gap   | 15.00 | 2026-11-20 | keeping  |
      | Belt |       |       | 2026-09-15 | refunded |
    When I go to the history page
    Then I should see "Hat" before "Dress"
    And I should see "Dress" before "Scarf"
    And I should see "Scarf" before "Shoes"
    And I should see "Shoes" before "Belt"
    And the "Hat" history entry should show "Gap"
    And the "Hat" history entry should show "$15.00"
```


---

## Feature 8: User settings
File: `features/settings.feature`

*"Remind me" options: 1, 2, 3 days before, or 1 week before. Stored in `users.reminder_days_before`.*

```gherkin
Feature: User settings
  As a shopper
  I want to choose how far ahead I am reminded
  So that reminders arrive when I can still act on them

  Background:
    Given I am logged in as "someone@example.com"

  Scenario: Reminder lead time defaults to 2 days
    Given I am on the purchases page
    When I follow "Settings"
    Then I should be on the settings page
    And the "Remind me" field should be set to "2 days before"

  Scenario: Change how far ahead I am reminded
    Given I am on the settings page
    When I select "1 week before" from "Remind me"
    And I press "Save settings"
    Then I should see "Settings updated"
    And the "Remind me" field should be set to "1 week before"
```


---

## Feature 9: Email reminders before a deadline
File: `features/reminders.feature`

*Tests use `:test` delivery, so mail lands in `ActionMailer::Base.deliveries`. The job runs daily (rake task `reminders:run`); Cucumber calls it directly.*

```
ReminderJob.run(today):
    Purchase.expire_overdue!(today)
    for each active or returning purchase with reminded_at nil
    and return_by - today <= user.reminder_days_before:
        email user: "Return <item> to <store> by <return_by>"  (or "Return <item> by <return_by>")
        reminded_at = now
```

```gherkin
Feature: Email reminders
  As a shopper
  I want an email before a return window closes
  So that I don't miss a deadline I forgot about

  Background:
    Given a user "someone@example.com" who wants reminders 2 days before
    And "someone@example.com" has the following purchases:
      | item   | store  | return_by  |
      | Jacket | Target | 2026-12-30 |

  Scenario: Reminder is sent on the right day
    Given today is 2026-12-28
    When the reminder job runs
    Then "someone@example.com" should receive 1 email
    And that email's subject should be "Return Jacket to Target by Dec 30, 2026"

  Scenario: Purchases without a store get reminders too
    Given "someone@example.com" has the following purchases:
      | item | return_by  |
      | Lamp | 2026-12-30 |
    And today is 2026-12-28
    When the reminder job runs
    Then "someone@example.com" should receive 2 emails
    And one email's subject should be "Return Lamp by Dec 30, 2026"

  Scenario Outline: Reminder respects the user's lead time
    Given "someone@example.com" wants reminders <lead> days before
    And today is <today>
    When the reminder job runs
    Then "someone@example.com" should receive <count> emails

    Examples:
      | lead | today      | count |
      | 2    | 2026-12-27 | 0     |
      | 2    | 2026-12-28 | 1     |
      | 7    | 2026-12-22 | 0     |
      | 7    | 2026-12-23 | 1     |

  Scenario: Each purchase gets only one reminder
    Given "someone@example.com" wants reminders 7 days before
    And today is 2026-12-23
    When the reminder job runs
    And today is 2026-12-24
    And the reminder job runs
    Then "someone@example.com" should receive 1 email

  Scenario Outline: Reminders depend on status
    Given "Jacket" has status "<status>"
    And today is 2026-12-28
    When the reminder job runs
    Then "someone@example.com" should receive <count> emails

    Examples:
      | status          | count |
      | active          | 1     |
      | returning       | 1     |
      | keeping         | 0     |
      | awaiting_refund | 0     |
      | refunded        | 0     |

  Scenario: Reminders go only to the purchase's owner
    Given a user "bob@example.com" who wants reminders 2 days before
    And "bob@example.com" has the following purchases:
      | item   | return_by  |
      | Kettle | 2027-01-20 |
    And today is 2026-12-28
    When the reminder job runs
    Then "someone@example.com" should receive 1 email
    And "bob@example.com" should receive no emails
```


---

## Step definitions to write (pseudocode)

Generic steps ("I fill in", "I press", "I follow", "I select", "I should see", "I should be on") come from `web_steps.rb`, with `features/support/paths.rb` mapping page names to routes. Placeholders: `ITEM` item, `E` email, `S` store, `T` text, `N` number, `D` date, `X` status, `F` field, `B` button, `M` CSS class.

```
# time_steps.rb
Given today is D                 → travel_to(Date.parse(D))        (midnight UTC)
After hook                       → travel_back

# user_steps.rb
Given a user exists with email E and password P
                                 → User.create!(email: E, password: P)
Given I am logged in as E        → create user E, visit login, fill form, submit
Given I am not logged in         → do nothing
When I log in with email E and password P
                                 → visit login, fill in, press "Log in"
When I sign up with email E and password P
                                 → fill sign up form with confirmation = P, press "Sign up"
Given a user E who wants reminders N days before
                                 → User.create!(email: E, password: ..., reminder_days_before: N)
Given E wants reminders N days before
                                 → update reminder_days_before

# store_steps.rb
Given I have a saved store S with a N day return window
                                 → StorePolicy.create!(user: U, store_name: S, window_days: N)
Then I should have a saved store S with a N day return window
                                 → current user has a policy with store S and window_days N
Then I should not see the save-store banner
                                 → have_no_css(".save-store-banner")
Then ITEM should be linked to the saved store "S · N day return"
                                 → policy = Purchase.find_by(item_name: ITEM).store_policy
                                   policy.store_name == S and policy.window_days == N

# form_steps.rb
Then the F field should contain V
                                 → expect(find_field(F).value).to eq(V)
Then the F field should be set to V
                                 → expect(page).to have_select(F, selected: V)

# purchase_steps.rb
Given [I have | E has] the following purchases:   (Cucumber data table)
                                 → for each row:
                                     Purchase.create!(user: U,
                                       item_name: row.item,
                                       store_name: row.store or nil,
                                       price: row.price or nil,
                                       purchase_date: row.purchase_date or nil,
                                       return_by: row.return_by,
                                       status: row.status or "active")
                                   (blank cells → nil; return_by is always given in tests
                                    so setup never depends on the resolution logic)
Given E has a purchase ITEM returnable by D
                                 → create user E if needed, then create purchase as above
When I add a purchase ITEM from store S with a N day window
                                 → visit new purchase page, fill item, store, window, submit
Given ITEM has status X          → Purchase.find_by(item_name: ITEM).update_columns(status: X)
                                   (skips validations so tests can set any state directly)
Then ITEM should have status X   → Purchase.find_by(item_name: ITEM).status == X
Given/When I am on / go to the edit page for ITEM
                                 → edit_purchase_path(Purchase.find_by(item_name: ITEM))

# card_steps.rb  (all scoped with `within` the card or history entry for ITEM)
card(ITEM) helper                → find(".card[data-item='ITEM']")
history_entry(ITEM) helper       → find(".history-entry[data-item='ITEM']")
the ITEM card / history entry should [not] show store S / return date D / status T / text T
                                 → within(element) { have_[no_]content(...) }
the ITEM card should not show a price
                                 → within(card(ITEM)) { have_no_css(".price") }
the ITEM card / history entry should be marked M
                                 → expect(element[:class]).to include(M)
I press B on the ITEM card / history entry
                                 → within(element) { click_button(B) }
I select S from the ITEM card's / history entry's "Status" dropdown
                                 → within(element) { select(S, from: "Status") }
I should [not] see a purchase card for ITEM
                                 → have_[no_]css(".card[data-item='ITEM']")
I should see FIRST before SECOND → page.body.index(FIRST) < page.body.index(SECOND)

# email_steps.rb
Before hook                      → ActionMailer::Base.deliveries.clear
When the reminder job runs       → ReminderJob.run(Date.current)
Then E should receive N email(s) / no emails
                                 → deliveries.count { |m| m.to.include?(E) } == N
Then that email's subject should be S
                                 → the only delivery to E has subject S
Then one email's subject should be S
                                 → some delivery to E has subject S
```
