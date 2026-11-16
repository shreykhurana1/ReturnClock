Feature: Change my account password
  As a signed-in shopper
  I want to change my password after proving I know the current one
  So that I can protect my account and sign out other devices

  Background:
    Given an account exists for "student@example.com" with password "Password1!"
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "student@example.com" and password "Password1!"
    And I open the profile menu
    And I follow "Account Settings"

  Scenario: Change my password and sign in again with the new password
    Then I should see "student@example.com" in the main content
    When I change my password using "Password1!" to "Different2!" with confirmation "Different2!"
    Then I should see the "Sign In" heading
    And I should see "Password changed. Please sign in again." in the main content
    When I visit the Dashboard directly
    Then I should see the "Sign In" heading
    When I sign in with email "student@example.com" and password "Password1!"
    Then I should see the "Sign In" heading
    And I should see "Try another email address or password." in the main content
    When I sign in with email "student@example.com" and password "Different2!"
    Then I should see the "Dashboard" heading

  Scenario: An incorrect current password leaves my account unchanged
    When I change my password using "WrongPass3!" to "Different2!" with confirmation "Different2!"
    Then I should see the "Account Settings" heading
    And I should see "Current password is incorrect." in the main content
    And the "Current Password" field should contain ""
    And the "New Password" field should contain ""
    And the "Confirm New Password" field should contain ""
    When I open the profile menu
    And I sign out
    Then I should see the "ReturnClock" heading
    When I follow "Sign In"
    And I sign in with email "student@example.com" and password "Password1!"
    Then I should see the "Dashboard" heading

  Scenario: Reject a password confirmation mismatch
    When I change my password using "Password1!" to "Different2!" with confirmation "Mismatch3!"
    Then I should see the "Account Settings" heading
    And I should see "Passwords do not match." in the main content
    And the "Current Password" field should contain ""
    And the "New Password" field should contain ""
    And the "Confirm New Password" field should contain ""
    When I follow "Back to Dashboard"
    Then I should see the "Dashboard" heading

  Scenario: Reject a new password that does not meet the requirements
    When I change my password using "Password1!" to "Aa1!" with confirmation "Aa1!"
    Then I should see the "Account Settings" heading
    And I should see "Use at least 8 characters." in the main content
    And the "Current Password" field should contain ""
    And the "New Password" field should contain ""
    And the "Confirm New Password" field should contain ""
    When I follow "Back to Dashboard"
    Then I should see the "Dashboard" heading
