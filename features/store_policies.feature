Feature: Maintain my store return policies
  As a shopper who buys from several stores
  I want to save their return windows and correct mistakes
  So that I can reuse the right policy when recording a purchase

  Scenario: Create policies from management and correct a duplicate store name
    Given an account exists for "shopper@example.com" with password "Password1!"
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "shopper@example.com" and password "Password1!"
    And I follow "Store Policies"
    Then I should see "No store policies yet." in the main content
    When I follow "Create Store Policy"
    And I create a store policy named "Campus Store" with a 30-day return window
    Then I should see the "Store Policies" heading
    And I should see "Campus Store" in the main content
    When I follow "Create Store Policy"
    And I create a store policy named "Campus Store" with a 14-day return window
    Then I should see the "Create Store Policy" heading
    And I should see "Store name has already been taken" in the main content
    And the "Store Name" field should contain "Campus Store"
    When I create a store policy named "Book Shop" with a 14-day return window
    Then I should see the "Store Policies" heading
    And I should see "Campus Store" in the main content
    And I should see "Book Shop" in the main content

  Scenario: Correct a missing store name and a nonpositive return window
    Given an account exists for "shopper@example.com" with password "Password1!"
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "shopper@example.com" and password "Password1!"
    And I follow "Store Policies"
    And I follow "Create Store Policy"
    And I create a store policy named "   " with a 0-day return window
    Then I should see the "Create Store Policy" heading
    And I should see "Store name can't be blank" in the main content
    And I should see "Window days must be greater than 0" in the main content
    And the "Return Window (days)" field should contain "0"
    When I create a store policy named "Campus Store" with a 30-day return window
    Then I should see the "Store Policies" heading
    And the "Campus Store" card should show "Return window: 30 days"

  Scenario: Save my own policy for a store another shopper already uses
    Given an account exists for "shopper@example.com" with password "Password1!"
    And an account exists for "other@example.com" with password "Password1!"
    And the account "other@example.com" has a policy named "Campus Store" with a 14-day return window
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "shopper@example.com" and password "Password1!"
    And I follow "Store Policies"
    And I follow "Create Store Policy"
    And I create a store policy named "Campus Store" with a 30-day return window
    Then I should see the "Store Policies" heading
    And the "Campus Store" card should show "Return window: 30 days"
    When I follow "Add Purchase"
    And I choose store policy "Campus Store"
    And I add a purchase named "My Textbook" costing "49.99" purchased today
    Then I should see the "Dashboard" heading
    And purchase "My Textbook" should have a deadline 30 days from today
