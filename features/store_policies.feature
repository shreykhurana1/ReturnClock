Feature: Save a store's return policy
  As a shopper
  I want ReturnClock to remember each store's return window
  So that next time I only have to type the store name

  Background:
    Given today is 2026-10-01
    And I am logged in as "someone@example.com"

  Scenario: Save a new store after adding a purchase
    When I add a purchase "Dress" from store "Zara" with a 30 day window
    Then I should be on the Dashboard
    And I should see 'Save store "Zara" with a 30 day return window?' in the main content
    When I press "Create Store Policy"
    Then I should see "Store return policy created." in the main content
    When I follow "Store Policies"
    Then the store policy "Zara" should have a 30 day return window
    And the store policy "Zara" should be in use

  Scenario: Decline saving a new store
    When I add a purchase "Dress" from store "Zara" with a 30 day window
    And I follow "No thanks"
    Then I should be on the Dashboard
    And I should not see the save-store banner
    When I follow "Store Policies"
    Then I should see "No store policies yet." in the main content

  Scenario: A saved store fills in the window when I leave it blank
    Given I have a saved store "Zara" with a 30 day return window
    And I am on the Add Purchase page
    When I fill in "Item Name" with "Skirt"
    And I fill in "Store" with "Zara"
    And I press "Add Purchase"
    Then the "Skirt" card should show return date "Oct 31, 2026"
    When I follow "Store Policies"
    Then the store policy "Zara" should be in use

  Scenario: No prompt when the store is already saved
    Given I have a saved store "Zara" with a 30 day return window
    When I add a purchase "Dress" from store "Zara" with a 30 day window
    Then I should not see the save-store banner

  Scenario: Store names match regardless of capitalization
    Given I have a saved store "Zara" with a 30 day return window
    When I add a purchase "Skirt" from store "zara" with a 30 day window
    Then I should not see the save-store banner
    When I follow "Store Policies"
    And I follow "Create Store Policy"
    And I create a store policy named "ZARA" with a 14-day return window
    Then I should be on the Create Store Policy page
    And I should see "Store name has already been taken" in the main content

  Scenario: Create policies from the Store Policies page and correct a duplicate store name
    Given I am on the Store Policies page
    Then I should see "No store policies yet." in the main content
    When I follow "Create Store Policy"
    And I create a store policy named "Campus Store" with a 30-day return window
    Then I should be on the Store Policies page
    And I should see "Campus Store" in the main content
    When I follow "Create Store Policy"
    And I create a store policy named "Campus Store" with a 14-day return window
    Then I should be on the Create Store Policy page
    And I should see "Store name has already been taken" in the main content
    And the "Store Name" field should contain "Campus Store"
    When I create a store policy named "Book Shop" with a 14-day return window
    Then I should be on the Store Policies page
    And I should see "Campus Store" in the main content
    And I should see "Book Shop" in the main content
