Feature: Purchase history
  As a shopper
  I want a separate page of purchases that are finished
  So that my main dashboard only shows what still needs action

  Background:
    Given today is 2026-12-01
    And I am logged in as "amy@example.com"
    And I have the following purchases:
      | item   | return_by  | status       |
      | Scarf  | 2026-10-31 | Keeping      |
      | Shoes  | 2026-10-31 | Refunded     |
      | Dress  | 2026-10-31 | Active       |
      | Jacket | 2026-12-30 | Active       |
      | Boots  | 2026-12-20 | Shipped back |

  Scenario: History lists only finished purchases
    Given I am on the Dashboard
    When I follow "History"
    Then I should see "Scarf" in the main content
    And I should see "Shoes" in the main content
    And I should see "Dress" in the main content
    And I should not see a purchase named "Jacket"
    And I should not see a purchase named "Boots"

  Scenario: Overdue purchases expire when I open History
    Given today is 2026-12-31
    When I go to History
    Then purchase "Jacket" should show status "Expired"
    And the "Jacket" card should show "Expired on" with the date "2026-12-30"
    And I should not see a purchase named "Boots"

  Scenario Outline: History entries are color coded by outcome
    When I go to History
    Then the "<item>" card should be marked "<outcome>"
    And purchase "<item>" should show status "<label>"

    Examples:
      | item  | outcome  | label    |
      | Scarf | kept     | Keeping  |
      | Shoes | refunded | Refunded |
      | Dress | expired  | Expired  |

  Scenario: Newest return-by date first, ties by name
    Given I have the following purchases:
      | item | store | price | return_by  | status   |
      | Hat  | Gap   | 15.00 | 2026-11-20 | Keeping  |
      | Belt |       |       | 2026-09-15 | Refunded |
    When I go to History
    Then I should see "Hat" before "Dress"
    And I should see "Dress" before "Scarf"
    And I should see "Scarf" before "Shoes"
    And I should see "Shoes" before "Belt"
    And the "Hat" card should show store "Gap"
    And the "Hat" card should show "$15.00"
