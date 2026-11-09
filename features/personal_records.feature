Feature: Find my purchases by return urgency
  As a signed-in shopper
  I want my own actionable returns on Dashboard and finished purchases in History
  So that I can focus on what still needs attention without seeing anyone else's data

  Scenario: See only my purchases and store policies
    Given an account exists for "shopper@example.com" with password "Password1!"
    And an account exists for "other@example.com" with password "Password1!"
    And the account "shopper@example.com" has these purchases:
      | item         | store        | return window | days ago | status  |
      | My Textbook  | Campus Store | 30            | 1        | Active  |
      | My Kept Book | Campus Store | 30            | 2        | Keeping |
    And the account "other@example.com" has these purchases:
      | item         | store         | return window | days ago | status   |
      | Private Bag  | Private Store | 14            | 1        | Active   |
      | Private Book | Private Store | 14            | 2        | Refunded |
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "shopper@example.com" and password "Password1!"
    Then I should see "My Textbook" in the main content
    And I should not see "Private Bag" in the main content
    When I follow "History"
    Then I should see "My Kept Book" in the main content
    And I should not see "Private Book" in the main content
    When I follow "Store Policies"
    Then I should see "Campus Store" in the main content
    And I should not see "Private Store" in the main content
    When I follow "Add Purchase"
    Then the available store policies should be:
      | Campus Store |

  Scenario: Keep overdue refunds actionable and show upcoming deadlines in order
    Given an account exists for "shopper@example.com" with password "Password1!"
    And the account "shopper@example.com" has these purchases:
      | item               | store        | return window | days ago | status         |
      | Later Return       | Campus Store | 30            | 10       | Active         |
      | Due Today          | Campus Store | 30            | 30       | Active         |
      | Expired Return     | Campus Store | 30            | 31       | Active         |
      | Refund In Progress | Campus Store | 30            | 40       | Refund Pending |
      | Shipped Return     | Campus Store | 30            | 41       | Shipped Back   |
      | Completed Return   | Campus Store | 30            | 2        | Refunded       |
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "shopper@example.com" and password "Password1!"
    Then the purchases should appear in this order:
      | Shipped Return     |
      | Refund In Progress |
      | Due Today          |
      | Later Return       |
    And I should not see a purchase named "Expired Return"
    And I should not see a purchase named "Completed Return"
    When I follow "History"
    Then I should see "Expired Return" in the main content
    And I should see "Completed Return" in the main content
    And I should not see a purchase named "Refund In Progress"
    And I should not see a purchase named "Shipped Return"

  @allow-rescue
  Scenario: Another shopper's purchase and policy editor URLs do not give me access
    Given an account exists for "shopper@example.com" with password "Password1!"
    And an account exists for "other@example.com" with password "Password1!"
    And the account "other@example.com" has a purchase named "Private Bag" from "Private Store" with a 14-day return window
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "shopper@example.com" and password "Password1!"
    And I open the purchase editor for "Private Bag" belonging to "other@example.com"
    Then I should see a page-not-found response
    And I should not see "Private Bag" in the main content
    When I open the policy editor for "Private Store" belonging to "other@example.com"
    Then I should see a page-not-found response
    And I should not see "Private Store" in the main content
    When I visit the Dashboard directly
    Then I should see the "Dashboard" heading
    And I should not see a purchase named "Private Bag"
