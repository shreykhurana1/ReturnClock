Feature: Choose when my return deadlines need urgent attention
  As a shopper
  I want to choose how early my active purchases become urgent
  So that my Dashboard reflects the time I need to arrange a return

  Scenario: Change the alert lead time and see a purchase become urgent
    Given an account exists for "shopper@example.com" with password "Password1!"
    And the account "shopper@example.com" has these purchases:
      | item | store        | return window | days ago | status |
      | Lamp | Campus Store | 30            | 25       | Active |
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "shopper@example.com" and password "Password1!"
    Then purchase "Lamp" should show an "amber" deadline indicator
    When I open the profile menu
    And I follow "Account Settings"
    And I set deadline alerts to "1 week before"
    Then I should see "Settings updated." in the main content
    When I follow "Dashboard"
    Then purchase "Lamp" should show a "red" deadline indicator
    And purchase "Lamp" should have a deadline 5 days from today
