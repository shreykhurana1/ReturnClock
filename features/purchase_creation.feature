Feature: Add a purchase
  As a shopper
  I want to log a purchase with only the details I have handy
  So that tracking a return never feels like a chore

  Background:
    Given today is 2026-10-01
    And I am logged in as "someone@example.com"

  Scenario: Minimal — just an item name and a return-by date
    Given I am on the Add Purchase page
    When I fill in "Item Name" with "Lamp"
    And I fill in "Purchase Date" with ""
    And I fill in "Return By" with "2026-12-01"
    And I press "Add Purchase"
    Then I should be on the Dashboard
    And the "Lamp" card should show return date "Dec 1, 2026"

  Scenario: Minimal — an item name, purchase date, and return window
    Given I am on the Add Purchase page
    When I fill in "Item Name" with "Lamp"
    And I fill in "Purchase Date" with "2026-09-20"
    And I fill in "Return Window (days)" with "30"
    And I press "Add Purchase"
    Then the "Lamp" card should show return date "Oct 20, 2026"

  Scenario: Full detail
    Given I am on the Add Purchase page
    When I fill in "Item Name" with "Jacket"
    And I fill in "Store" with "Target"
    And I fill in "Price" with "60.00"
    And I fill in "Purchase Date" with "2026-10-01"
    And I fill in "Return Window (days)" with "90"
    And I press "Add Purchase"
    Then the "Jacket" card should show store "Target"
    And the "Jacket" card should show "$60.00"
    And the "Jacket" card should show return date "Dec 30, 2026"

  Scenario: If the window and return-by disagree, return-by wins
    Given I am on the Add Purchase page
    When I fill in "Item Name" with "Lamp"
    And I fill in "Purchase Date" with "2026-10-01"
    And I fill in "Return Window (days)" with "30"
    And I fill in "Return By" with "2026-11-15"
    And I press "Add Purchase"
    Then the "Lamp" card should show return date "Nov 15, 2026"
    When I press "Edit" on the "Lamp" card
    Then the "Return Window (days)" field should contain "45"

  Scenario: A purchase with a past deadline is logged as expired
    Given I am on the Add Purchase page
    When I fill in "Item Name" with "Boots"
    And I fill in "Purchase Date" with "2026-08-01"
    And I fill in "Return By" with "2026-08-31"
    And I press "Add Purchase"
    Then I should be on History
    And I should see 'The return-by date has passed, so "Boots" was logged as expired.' in the main content
    And purchase "Boots" should show status "Expired"
    When I follow "Dashboard"
    Then I should not see a purchase named "Boots"

  Scenario Outline: Record a purchase with my current return decision
    Given I have a saved store "Campus Store" with a 30 day return window
    And I am on the Add Purchase page
    When I fill in "Store" with "Campus Store"
    And I select "<status>" from "Status"
    And I add a purchase named "Textbook" costing "49.99" purchased today
    Then I should be on <page>
    And I should see "Textbook" in the main content
    And the purchase should have a return deadline 30 days from today
    When I follow "<other page>"
    Then I should not see a purchase named "Textbook"

    Examples:
      | status         | page      | other page |
      | Keeping        | History   | Dashboard  |
      | Refunded       | History   | Dashboard  |
      | Refund Pending | Dashboard | History    |

  Scenario: Correct a missing item name without re-entering the purchase details
    Given I have a saved store "Campus Store" with a 30 day return window
    And I am on the Add Purchase page
    When I fill in "Store" with "Campus Store"
    And I select "Keeping" from "Status"
    And I add a purchase named "   " costing "49.99" purchased today
    Then I should be on the Add Purchase page
    And I should see "Item name can't be blank" in the main content
    And the "Store" field should contain "Campus Store"
    And the "Status" field should be set to "Keeping"
    And the purchase price should be "49.99"
    When I correct the item name to "Textbook"
    Then I should be on History
    And I should see "Textbook" in the main content

  Scenario Outline: Missing or invalid details are rejected
    Given I am on the Add Purchase page
    When I fill in "Item Name" with "<item>"
    And I fill in "Price" with "<price>"
    And I fill in "Purchase Date" with "<purchase_date>"
    And I fill in "Return Window (days)" with "<window>"
    And I fill in "Return By" with "<return_by>"
    And I press "Add Purchase"
    Then I should be on the Add Purchase page
    And I should see "<error>" in the main content

    Examples:
      | item | price | purchase_date | window | return_by  | error                                                      |
      | Lamp |       |               |        |            | Add a return-by date, or a purchase date and return window |
      | Lamp |       | 2026-10-01    |        |            | Add a return-by date, or a purchase date and return window |
      |      |       | 2026-10-01    | 30     |            | Item name can't be blank                                   |
      | Lamp |       | 2026-10-01    |        | 2026-09-25 | Return by can't be before the purchase date                |
      | Lamp | -5    | 2026-10-01    | 30     |            | Price must be greater than 0                               |
      | Lamp |       | 2026-10-01    | -3     |            | Return window can't be negative                            |
