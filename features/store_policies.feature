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
