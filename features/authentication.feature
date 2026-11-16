Feature: Account access
  As a shopper
  I want my own private account
  So that only I can see my purchases and return deadlines

  Scenario: Sign up with an email and password
    Given I visit the landing page
    When I follow "Create Account"
    And I sign up with email "someone@example.com" and password "Password1!"
    Then I should be on the Dashboard
    And I should see "Account created successfully!" in the main content
    And I should see "Demo preview" in the main content

  Scenario: Cannot sign up with an email that is already taken
    Given a user exists with email "someone@example.com" and password "Password1!"
    And I visit the landing page
    When I follow "Create Account"
    And I sign up with email "someone@example.com" and password "Password1!"
    Then I should be on the Create Account page
    And I should see "Email address has already been taken" in the main content
    And the "Email" field should contain "someone@example.com"
    And the "Password" field should contain ""
    And the "Confirm Password" field should contain ""
    When I go to the Dashboard
    Then I should be on the Sign In page

  Scenario: Cannot sign up when passwords do not match
    Given I visit the landing page
    When I follow "Create Account"
    And I fill in "Email" with "someone@example.com"
    And I fill in "Password" with "Password1!"
    And I fill in "Confirm Password" with "Different1!"
    And I press "Create Account"
    Then I should be on the Create Account page
    And I should see "Passwords do not match." in the main content

  Scenario: Log in with correct credentials
    Given a user exists with email "someone@example.com" and password "Password1!"
    And I visit the landing page
    When I follow "Sign In"
    And I log in with email "someone@example.com" and password "Password1!"
    Then I should be on the Dashboard
    When I open the profile menu
    And I follow "Account Settings"
    Then I should be on the Account Settings page
    And I should see "someone@example.com" in the main content

  Scenario: Log in with the wrong password
    Given a user exists with email "someone@example.com" and password "Password1!"
    And I visit the landing page
    When I follow "Sign In"
    And I log in with email "someone@example.com" and password "WrongPassword1!"
    Then I should be on the Sign In page
    And I should see "Try another email address or password." in the main content
    And the "Email" field should contain "someone@example.com"
    And the "Password" field should contain ""
    When I go to the Dashboard
    Then I should be on the Sign In page

  Scenario: Log out
    Given I am logged in as "someone@example.com"
    When I open the profile menu
    And I press "Sign Out"
    Then I should be on the Sign In page
    When I go to the Dashboard
    Then I should be on the Sign In page

  Scenario: Logged-out visitors are sent to the login page
    Given a user exists with email "someone@example.com" and password "Password1!"
    And I am not logged in
    When I go to History
    Then I should be on the Sign In page
    When I log in with email "someone@example.com" and password "Password1!"
    Then I should be on History
    And I should see "Demo preview" in the main content
    When I follow "Dashboard"
    Then I should be on the Dashboard
