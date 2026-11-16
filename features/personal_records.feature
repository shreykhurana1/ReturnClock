Feature: Find my purchases by return urgency
  As a signed-in shopper
  I want my own actionable returns on Dashboard and finished purchases in History
  So that I can focus on what still needs attention without seeing anyone else's data

  Scenario: Users only see their own purchases and store policies
    Given a user exists with email "someone@example.com" and password "Password1!"
    And a user exists with email "bob@example.com" and password "Password1!"
    And the account "someone@example.com" has these purchases:
      | item         | store        | return window | days ago | status  |
      | My Textbook  | Campus Store | 30            | 1        | Active  |
      | My Kept Book | Campus Store | 30            | 2        | Keeping |
    And the account "bob@example.com" has these purchases:
      | item         | store         | return window | days ago | status   |
      | Bob's Lamp   | Private Store | 14            | 1        | Active   |
      | Private Book | Private Store | 14            | 2        | Refunded |
    When I am logged in as "someone@example.com"
    Then I should see "My Textbook" in the main content
    And I should not see "Bob's Lamp" in the main content
    When I follow "History"
    Then I should see "My Kept Book" in the main content
    And I should not see "Private Book" in the main content
    When I follow "Store Policies"
    Then I should see "Campus Store" in the main content
    And I should not see "Private Store" in the main content
    When I follow "Add Purchase"
    And I fill in "Item Name" with "Borrowed Bag"
    And I fill in "Store" with "Private Store"
    And I press "Add Purchase"
    Then I should see "Add a return-by date, or a purchase date and return window" in the main content

  Scenario: Keep overdue refunds actionable and show upcoming deadlines in order
    Given a user exists with email "someone@example.com" and password "Password1!"
    And the account "someone@example.com" has these purchases:
      | item               | store        | return window | days ago | status         |
      | Later Return       | Campus Store | 30            | 10       | Active         |
      | Due Today          | Campus Store | 30            | 30       | Active         |
      | Expired Return     | Campus Store | 30            | 31       | Active         |
      | Refund In Progress | Campus Store | 30            | 40       | Refund Pending |
      | Shipped Return     | Campus Store | 30            | 41       | Shipped Back   |
      | Completed Return   | Campus Store | 30            | 2        | Refunded       |
    When I am logged in as "someone@example.com"
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
  Scenario: Another shopper's purchase and policy editor URLs are not found
    Given a user exists with email "other@example.com" and password "Password1!"
    And the account "other@example.com" has these purchases:
      | item        | store         | return window | days ago | status |
      | Private Bag | Private Store | 14            | 1        | Active |
    And I am logged in as "someone@example.com"
    When I open the purchase editor for "Private Bag" belonging to "other@example.com"
    Then I should see a page-not-found response
    And I should not see "Private Bag" in the main content
    When I open the policy editor for "Private Store" belonging to "other@example.com"
    Then I should see a page-not-found response
    And I should not see "Private Store" in the main content
    When I go to the Dashboard
    Then I should be on the Dashboard
    And I should not see a purchase named "Private Bag"
