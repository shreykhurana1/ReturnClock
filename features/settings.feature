Feature: User settings
  As a shopper
  I want to choose how far ahead I am reminded
  So that reminders arrive when I can still act on them

  Background:
    Given I am logged in as "amy@example.com"

  Scenario: Reminder lead time defaults to 2 days
    When I open the profile menu
    And I follow "Account Settings"
    Then I should be on the Account Settings page
    And the "Remind me" field should be set to "2 days before"

  Scenario: Change how far ahead I am reminded
    Given I am on the Account Settings page
    When I select "1 week before" from "Remind me"
    And I press "Save settings"
    Then I should see "Settings updated" in the main content
    And the "Remind me" field should be set to "1 week before"
