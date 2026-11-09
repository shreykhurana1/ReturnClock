Feature: Record a first purchase
  As a new ReturnClock user
  I want to save a store's return policy and a purchase
  So that I can see my return deadline on the Dashboard

  Scenario: Create my first store policy and purchase through the website
    Given an account exists for "shopper@example.com" with password "Password1!"
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "shopper@example.com" and password "Password1!"
    And I follow "Add Purchase"
    Then I should see "Create a store return policy before adding your first purchase." in the main content
    When I follow "Create Store Policy"
    And I create a store policy named "Campus Store" with a 30-day return window
    Then the store policy "Campus Store" should be selected
    And the purchase status "Active" should be selected
    When I add a purchase named "Textbook" costing "49.99" purchased today
    Then I should see the "Dashboard" heading
    And I should see "Textbook" in the main content
    And I should see "Campus Store" in the main content
    And I should see "$49.99" in the main content
    And the purchase should have a return deadline 30 days from today

  Scenario Outline: Record a purchase with my current return decision
    Given an account exists for "shopper@example.com" with password "Password1!"
    And the account "shopper@example.com" has a policy named "Campus Store" with a 30-day return window
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "shopper@example.com" and password "Password1!"
    And I follow "Add Purchase"
    And I choose store policy "Campus Store"
    And I choose purchase status "<status>"
    And I add a purchase named "Textbook" costing "49.99" purchased today
    Then I should see the "<page>" heading
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
    Given an account exists for "shopper@example.com" with password "Password1!"
    And the account "shopper@example.com" has a policy named "Campus Store" with a 30-day return window
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "shopper@example.com" and password "Password1!"
    And I follow "Add Purchase"
    And I choose store policy "Campus Store"
    And I choose purchase status "Keeping"
    And I add a purchase named "   " costing "49.99" purchased today
    Then I should see the "Add Purchase" heading
    And I should see "Item name can't be blank" in the main content
    And the store policy "Campus Store" should be selected
    And the purchase status "Keeping" should be selected
    And the purchase price should be "49.99"
    When I correct the item name to "Textbook"
    Then I should see the "History" heading
    And I should see "Textbook" in the main content
