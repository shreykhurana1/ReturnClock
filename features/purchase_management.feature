Feature: Edit a purchase
  As a shopper
  I want to fix or fill in details later
  So that I can start minimal and add more when I have the receipt

  Background:
    Given I am logged in as "someone@example.com"
    And I have a purchase "Textbook" from "Campus Store" with a 30 day return window
    And I have a saved store "Book Shop" with a 14 day return window
    And I am on the Dashboard

  Scenario: Edit a purchase from its card
    When I press "Edit" on the "Textbook" card
    And I save the purchase as "Updated Textbook" costing "35.00" bought 2 days ago using "Book Shop"
    Then I should be on the Dashboard
    And purchase "Updated Textbook" should have a deadline 12 days from today
    When I set purchase "Updated Textbook" to status "Keeping"
    Then I should be on History
    When I set purchase "Updated Textbook" to status "Returning"
    Then I should be on the Dashboard
    When I set purchase "Updated Textbook" to status "Refunded"
    Then I should be on History
    And I should see "Refunded" in the main content

  Scenario: Item name can't be removed
    When I press "Edit" on the "Textbook" card
    And I fill in "Item Name" with ""
    And I press "Save Purchase"
    Then I should see "Item name can't be blank" in the main content

  Scenario: Delete a purchase logged by mistake
    When I ask to delete purchase "Textbook"
    Then I should be on the Delete Purchase page
    And I should see "This cannot be undone." in the main content
    When I follow "Cancel"
    Then I should be on the Dashboard
    And I should see "Textbook" in the main content
    When I ask to delete purchase "Textbook"
    And I confirm purchase deletion
    Then I should be on the Dashboard
    And I should not see a purchase named "Textbook"
    And I should see "Purchase deleted." in the main content

  Scenario: Delete a finished purchase from History
    When I set purchase "Textbook" to status "Keeping"
    Then I should be on History
    When I ask to delete purchase "Textbook"
    And I follow "Cancel"
    Then I should be on History
    And I should see "Textbook" in the main content
    When I ask to delete purchase "Textbook"
    And I confirm purchase deletion
    Then I should be on History
    And I should not see a purchase named "Textbook"

  Scenario: Change a purchase's status from the dropdown on its card
    When I quickly update purchase "Textbook" to status "Keeping"
    Then I should be on History
    And purchase "Textbook" should show status "Keeping"
    When I quickly update purchase "Textbook" to status "Returning"
    Then I should be on the Dashboard
    And purchase "Textbook" should show status "Returning"
    When I quickly update purchase "Textbook" to status "Shipped back"
    Then purchase "Textbook" should show status "Shipped back"
    When I quickly update purchase "Textbook" to status "Refund pending"
    Then purchase "Textbook" should show status "Refund pending"
    When I quickly update purchase "Textbook" to status "Refunded"
    Then I should be on History
    And purchase "Textbook" should show status "Refunded"
    When I quickly update purchase "Textbook" to status "Active"
    Then I should be on the Dashboard
    And purchase "Textbook" should show status "Active"

  Scenario: Edit a store policy without changing an existing purchase's deadline
    When I follow "Store Policies"
    Then I should be on the Store Policies page
    And I should see "In use by purchases; cannot be deleted." in the main content
    When I change policy "Campus Store" to a 60-day return window
    And I follow "Dashboard"
    Then purchase "Textbook" should have a deadline 30 days from today
    When I follow "Add Purchase"
    And I fill in "Store" with "Campus Store"
    And I add a purchase named "New Textbook" costing "20.00" purchased today
    Then purchase "Textbook" should have a deadline 30 days from today
    And purchase "New Textbook" should have a deadline 60 days from today
