Feature: Manage access to ReturnClock
  As a shopper tracking return deadlines
  I want to create an account and sign in securely
  So that I can access my own ReturnClock pages

  Scenario: Create an account from the public landing page
    Given I visit the landing page
    When I follow "Create Account"
    And I sign up with email "new@example.com" and password "Password1!"
    Then I should see the "Dashboard" heading
    And I should see "Account created successfully!" in the main content
    And I should see "Demo preview" in the main content

  Scenario: Reject signup when password confirmation does not match
    Given I visit the landing page
    When I follow "Create Account"
    And I fill in "Email" with "new@example.com"
    And I fill in "Password" with "Password1!"
    And I fill in "Confirm Password" with "Different1!"
    And I press "Create Account"
    Then I should see the "Create Account" heading
    And I should see "Passwords do not match." in the main content
    And the "Email" field should contain "new@example.com"
    And the "Password" field should contain ""
    And the "Confirm Password" field should contain ""
    When I visit the Dashboard directly
    Then I should see the "Sign In" heading

  Scenario: Reject signup with an email that already has an account
    Given an account exists for "student@example.com" with password "Password1!"
    And I visit the landing page
    When I follow "Create Account"
    And I sign up with email "student@example.com" and password "Password1!"
    Then I should see the "Create Account" heading
    And I should see "Email address has already been taken" in the main content
    And the "Email" field should contain "student@example.com"
    And the "Password" field should contain ""
    And the "Confirm Password" field should contain ""
    When I visit the Dashboard directly
    Then I should see the "Sign In" heading

  Scenario: Sign in and open my account settings from the profile menu
    Given an account exists for "student@example.com" with password "Password1!"
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "student@example.com" and password "Password1!"
    Then I should see the "Dashboard" heading
    When I open the profile menu
    And I follow "Account Settings"
    Then I should see the "Account Settings" heading
    And I should see "student@example.com" in the main content
    And I should see "More account settings coming soon." in the main content

  Scenario: Reject sign-in with an incorrect password
    Given an account exists for "student@example.com" with password "Password1!"
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "student@example.com" and password "WrongPassword1!"
    Then I should see the "Sign In" heading
    And I should see "Try another email address or password." in the main content
    And the "Email" field should contain "student@example.com"
    And the "Password" field should contain ""
    When I visit the Dashboard directly
    Then I should see the "Sign In" heading

  Scenario: Sign out and lose access to the Dashboard
    Given an account exists for "student@example.com" with password "Password1!"
    And I visit the landing page
    When I follow "Sign In"
    And I sign in with email "student@example.com" and password "Password1!"
    And I open the profile menu
    And I sign out
    Then I should see the "Sign In" heading
    When I visit the Dashboard directly
    Then I should see the "Sign In" heading

  Scenario: Sign in before accessing History and return to the requested page
    Given an account exists for "student@example.com" with password "Password1!"
    When I visit History directly
    Then I should see the "Sign In" heading
    When I sign in with email "student@example.com" and password "Password1!"
    Then I should see the "History" heading
    And I should see "Demo preview" in the main content
    When I follow "Dashboard"
    Then I should see the "Dashboard" heading
