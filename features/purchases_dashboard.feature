Feature: Purchases dashboard
  As a shopper
  I want to see everything I can still return, soonest deadline first
  So that I return things before it is too late

  Background:
    Given today is 2026-10-15
    And I am logged in as "amy@example.com"

  Scenario: A card shows the details I entered
    Given I have the following purchases:
      | item   | store  | price | purchase_date | return_by  |
      | Jacket | Target | 60.00 | 2026-10-01    | 2026-12-30 |
      | Lamp   |        |       |               | 2026-12-01 |
    When I go to the Dashboard
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
    When I go to the Dashboard
    Then the "Lamp" card should show "<days_text>"
    And the "Lamp" card should be marked "<urgency>"

    Examples:
      | return_by  | days_text   | urgency |
      | 2026-10-15 | Due today   | urgent  |
      | 2026-10-18 | 3 days left | urgent  |
      | 2026-10-19 | 4 days left | soon    |
      | 2026-10-22 | 7 days left | soon    |
      | 2026-10-23 | 8 days left | safe    |

  Scenario: Shipped-back and refund-pending cards get their own color, no countdown, and keep their deadline order
    Given I have the following purchases:
      | item   | return_by  | status         |
      | Jacket | 2026-12-30 | Active         |
      | Shoes  | 2026-10-16 | Shipped back   |
      | Boots  | 2026-10-17 | Refund pending |
    When I go to the Dashboard
    Then the "Shoes" card should be marked "awaiting"
    And the "Shoes" card should not show "1 day left"
    And purchase "Shoes" should show status "Shipped back"
    And the "Boots" card should be marked "awaiting"
    And the "Boots" card should not show "2 days left"
    And purchase "Boots" should show status "Refund pending"
    And I should see "Shoes" before "Boots"
    And I should see "Boots" before "Jacket"

  Scenario: Money at risk counts only priced items I can still return
    Given I have the following purchases:
      | item   | price | return_by  | status       |
      | Jacket | 60.00 | 2026-12-30 | Active       |
      | Dress  | 25.00 | 2026-10-31 | Returning    |
      | Lamp   |       | 2026-12-01 | Active       |
      | Scarf  | 20.00 | 2026-10-31 | Keeping      |
      | Shoes  | 50.00 | 2026-10-31 | Refunded     |
      | Boots  | 30.00 | 2026-10-31 | Shipped back |
      | Mixer  | 40.00 | 2026-10-10 | Active       |
    When I go to the Dashboard
    Then the "Money at risk" stat should show "$85.00"
