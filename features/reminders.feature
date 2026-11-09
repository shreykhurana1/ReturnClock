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

  Scenario: Missed deadlines get no reminder
    Given today is 2026-12-31
    When the reminder job runs
    Then "someone@example.com" should receive no emails

  Scenario Outline: Reminders depend on status
    Given "Jacket" has status "<status>"
    And today is 2026-12-28
    When the reminder job runs
    Then "someone@example.com" should receive <count> emails

    Examples:
      | status         | count |
      | Active         | 1     |
      | Returning      | 1     |
      | Keeping        | 0     |
      | Shipped back   | 0     |
      | Refund pending | 0     |
      | Refunded       | 0     |

  Scenario: Reminders go only to the purchase's owner
    Given a user "bob@example.com" who wants reminders 2 days before
    And "bob@example.com" has the following purchases:
      | item   | return_by  |
      | Kettle | 2027-01-20 |
    And today is 2026-12-28
    When the reminder job runs
    Then "someone@example.com" should receive 1 email
    And "bob@example.com" should receive no emails
