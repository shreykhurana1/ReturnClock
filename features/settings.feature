Feature: User settings
  As a shopper
  I want to choose how far ahead I am reminded
  So that reminders arrive when I can still act on them

  Background:
    Given I am logged in as "someone@example.com"

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

  Scenario: Time zone defaults to UTC
    When I am on the Account Settings page
    Then the "Time zone" field should be set to "(GMT+00:00) UTC"

  Scenario: Days left follow my time zone
    Given I have the following purchases:
      | item | return_by  |
      | Lamp | 2026-11-10 |
    And the time is 2026-11-09 23:30 UTC
    When I go to the Dashboard
    Then the "Lamp" card should show "1 day left"
    When I am on the Account Settings page
    And I select "(GMT+09:00) Tokyo" from "Time zone"
    And I press "Save time zone"
    Then I should see "Settings updated" in the main content
    When I go to the Dashboard
    Then the "Lamp" card should show "Due today"
