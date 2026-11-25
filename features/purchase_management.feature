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

  Scenario: Create a missing policy while editing a purchase without re-entering my changes
    When I edit purchase "Textbook"
    And I fill in "Item Name" with "Updated Textbook"
    And I fill in "Price" with "35.00"
    And I fill in "Purchase Date" with "2026-11-07"
    And I choose purchase status "Returning"
    And I press "Create Store Policy"
    And I create a store policy named "   " with a 45-day return window
    Then I should see the "Create Store Policy" heading
    And the "Store Name" field should explain "Store name can't be blank"
    When I create a store policy named "New Store" with a 45-day return window
    Then I should see the "Edit Purchase" heading
    And the "Item Name" field should contain "Updated Textbook"
    And the "Price" field should contain "35.00"
    And the "Purchase Date" field should contain "2026-11-07"
    And the purchase status "Returning" should be selected
    And the store policy "New Store — 45 days" should be selected
    When I press "Save Purchase"
    Then I should see the "Dashboard" heading
    And purchase "Updated Textbook" should have a deadline 43 days from today

  Scenario: Return from policy creation to my unsaved purchase edits
    When I edit purchase "Textbook"
    And I fill in "Item Name" with "Kept Textbook"
    And I fill in "Price" with "35.00"
    And I choose store policy "Book Shop"
    And I choose purchase status "Keeping"
    And I press "Create Store Policy"
    And I fill in "Store Name" with "Unused Store"
    And I follow "Cancel"
    Then the "Item Name" field should contain "Kept Textbook"
    And the "Price" field should contain "35.00"
    And the store policy "Book Shop — 14 days" should be selected
    And the purchase status "Keeping" should be selected
    When I press "Save Purchase"
    Then I should see the "History" heading
    And purchase "Kept Textbook" should have a deadline 14 days from today
    When I follow "Store Policies"
    Then I should not see "Unused Store" in the main content

  Scenario: Cancel a purchase deletion before confirming it
    When I ask to delete purchase "Textbook"
    Then I should see the "Delete Purchase" heading
    And I should see "This cannot be undone." in the main content
    When I follow "Cancel"
    Then I should see the "Dashboard" heading
    Then I should see "Textbook" in the main content
    When I ask to delete purchase "Textbook"
    And I confirm purchase deletion
    Then I should see the "Dashboard" heading
    And I should not see a purchase named "Textbook"
    And I should see "Purchase deleted." in the main content

  Scenario: Update my return decision directly from a purchase card
    When I quickly update purchase "Textbook" to status "Keeping"
    Then I should see the "History" heading
    And purchase "Textbook" should show status "Keeping"
    When I quickly update purchase "Textbook" to status "Returning"
    Then I should see the "Dashboard" heading
    And purchase "Textbook" should show status "Returning"
    When I quickly update purchase "Textbook" to status "Shipped back"
    Then purchase "Textbook" should show status "Shipped back"
    When I quickly update purchase "Textbook" to status "Refund pending"
    Then purchase "Textbook" should show status "Refund pending"
    When I quickly update purchase "Textbook" to status "Refunded"
    Then I should see the "History" heading
    And purchase "Textbook" should show status "Refunded"
    When I quickly update purchase "Textbook" to status "Active"
    Then I should see the "Dashboard" heading
    And purchase "Textbook" should show status "Active"

  Scenario: Track a return and refund using the card's quick-action buttons
    When I choose "Return it" for purchase "Textbook"
    Then I should see the "Dashboard" heading
    And purchase "Textbook" should show status "Returning"
    When I choose "Sent it back" for purchase "Textbook"
    Then purchase "Textbook" should show status "Shipped back"
    And purchase "Textbook" should show "Shipped back on" dated today
    When I choose "Refund received" for purchase "Textbook"
    Then I should see the "History" heading
    And purchase "Textbook" should show status "Refunded"
    And purchase "Textbook" should show "Refunded on" dated today
    When I follow "Dashboard"
    Then I should not see a purchase named "Textbook"

  Scenario: Start a return for an expired purchase from History
    When I edit purchase "Textbook"
    And I save the purchase as "Textbook" costing "49.99" bought 40 days ago using "Campus Store"
    Then I should see the "History" heading
    And purchase "Textbook" should show status "Expired"
    When I quickly update purchase "Textbook" to status "Returning"
    Then I should see the "Dashboard" heading
    And purchase "Textbook" should show status "Returning"
    When I follow "History"
    Then I should not see a purchase named "Textbook"
    When I follow "Dashboard"
    And I quickly update purchase "Textbook" to status "Active"
    Then I should see the "History" heading
    And purchase "Textbook" should show status "Expired"

  Scenario: Cancel and confirm deletion of a purchase in History
    When I set purchase "Textbook" to status "Keeping"
    Then I should see the "History" heading
    When I ask to delete purchase "Textbook"
    And I follow "Cancel"
    Then I should see the "History" heading
    And I should see "Textbook" in the main content
    When I ask to delete purchase "Textbook"
    And I confirm purchase deletion
    Then I should see the "History" heading
    And I should not see a purchase named "Textbook"

  Scenario: Edit a store policy without changing an existing purchase's deadline
    When I follow "Store Policies"
    Then I should see the "Store Policies" heading
    And the "Campus Store" policy should explain why deletion is disabled
    When I change policy "Campus Store" to a 60-day return window
    And I follow "Dashboard"
    Then purchase "Textbook" should have a deadline 30 days from today
    When I follow "Add Purchase"
    And I choose store policy "Campus Store"
    And I add a purchase named "New Textbook" costing "20.00" purchased today
    Then purchase "Textbook" should have a deadline 30 days from today
    And purchase "New Textbook" should have a deadline 60 days from today

  Scenario: Reject invalid edits without changing the saved purchase
    When I edit purchase "Textbook"
    And I fill in "Item Name" with "   "
    And I fill in "Price" with "-5"
    And I press "Save Purchase"
    Then I should see the "Edit Purchase" heading
    And I should see "Item name can't be blank" in the main content
    And I should see "Price must be greater than or equal to 0" in the main content
    And the "Item Name" field should explain "Item name can't be blank"
    And the "Price" field should explain "Price must be greater than or equal to 0"
    And the purchase price should be "-5"
    And the store policy "Campus Store — 30 days" should be selected
    When I follow "Back to Dashboard"
    Then the "Textbook" card should show "$49.99"
    And purchase "Textbook" should have a deadline 30 days from today
    When I edit purchase "Textbook"
    And I save the purchase as "Corrected Textbook" costing "35.00" bought 2 days ago using "Book Shop"
    Then I should see the "Dashboard" heading
    And the "Corrected Textbook" card should show "$35.00"
    And purchase "Corrected Textbook" should have a deadline 12 days from today
