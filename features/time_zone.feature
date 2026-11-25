Feature: Keep my return deadlines on my own calendar
  As a shopper
  I want to choose my time zone
  So that "today" and the days left on my purchases match where I actually am

  Scenario: Save a time zone from account settings
    Given an account exists for "shopper@example.com" with password "Password1!"
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "shopper@example.com" and password "Password1!"
    And I open the profile menu
    And I follow "Account Settings"
    And I set my time zone to "Auckland"
    Then I should see "Settings updated." in the main content
    And my time zone should be saved as "Auckland" for "shopper@example.com"
