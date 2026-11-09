Feature: Manage purchases and saved store policies
  As a ReturnClock user
  I want to keep my purchases and store policies up to date
  So that my Dashboard and History reflect my return plans

  Background:
    Given an account exists for "shopper@example.com" with password "Password1!"
    And the account "shopper@example.com" has a purchase named "Textbook" from "Campus Store" with a 30-day return window
    And the account "shopper@example.com" has a policy named "Book Shop" with a 14-day return window
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "shopper@example.com" and password "Password1!"

  Scenario: Edit a purchase and move it between Dashboard and History using its status
    When I edit purchase "Textbook"
    And I save the purchase as "Updated Textbook" costing "35.00" bought 2 days ago using "Book Shop"
    Then I should see the "Dashboard" heading
    And purchase "Updated Textbook" should have a deadline 12 days from today
    When I set purchase "Updated Textbook" to status "Keeping"
    Then I should see the "History" heading
    When I set purchase "Updated Textbook" to status "Returning"
    Then I should see the "Dashboard" heading
    When I set purchase "Updated Textbook" to status "Refunded"
    Then I should see the "History" heading
    And I should see "Refunded" in the main content

  Scenario: Cancel a purchase deletion before confirming it
    When I ask to delete purchase "Textbook"
    Then I should see the "Delete Purchase" heading
    And I should see "This cannot be undone." in the main content
    When I follow "Cancel"
    And I follow "Back to Dashboard"
    Then I should see "Textbook" in the main content
    When I ask to delete purchase "Textbook"
    And I confirm purchase deletion
    Then I should see the "Dashboard" heading
    And I should not see a purchase named "Textbook"
    And I should see "Purchase deleted." in the main content

  Scenario: Edit a store policy without changing an existing purchase's deadline
    When I follow "Store Policies"
    Then I should see the "Store Policies" heading
    And I should see "In use by purchases; cannot be deleted." in the main content
    When I change policy "Campus Store" to a 60-day return window
    And I follow "Dashboard"
    Then purchase "Textbook" should have a deadline 30 days from today
    When I follow "Add Purchase"
    And I choose store policy "Campus Store"
    And I add a purchase named "New Textbook" costing "20.00" purchased today
    Then purchase "Textbook" should have a deadline 30 days from today
    And purchase "New Textbook" should have a deadline 60 days from today
