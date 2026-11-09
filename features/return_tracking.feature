Feature: Track a return
  As a shopper
  I want changing a purchase's status to take one click
  So that keeping my returns up to date is effortless

  Background:
    Given today is 2026-10-15
    And I am logged in as "someone@example.com"
    And I have the following purchases:
      | item   | price | return_by  |
      | Jacket | 60.00 | 2026-12-30 |

  Scenario Outline: Quick buttons move a purchase to its next status
    Given "Jacket" has status "<from>"
    And I am on the Dashboard
    When I press "<button>" on the "Jacket" card
    Then purchase "Jacket" should show status "<to>"

    Examples:
      | from           | button          | to           |
      | Active         | Keep it         | Keeping      |
      | Active         | Return it       | Returning    |
      | Returning      | Sent it back    | Shipped back |
      | Shipped back   | Refund received | Refunded     |
      | Refund pending | Refund received | Refunded     |

  Scenario Outline: Each card offers only the quick buttons that apply
    Given "Jacket" has status "<status>"
    When I go to <page>
    Then the "Jacket" card should only offer "<buttons>"

    Examples:
      | status         | page      | buttons            |
      | Active         | Dashboard | Keep it, Return it |
      | Returning      | Dashboard | Sent it back       |
      | Shipped back   | Dashboard | Refund received    |
      | Refund pending | Dashboard | Refund received    |
      | Keeping        | History   |                    |
      | Refunded       | History   |                    |

  Scenario: Keeping an item moves it to History
    Given I am on the Dashboard
    When I press "Keep it" on the "Jacket" card
    Then I should be on History
    And purchase "Jacket" should show status "Keeping"
    When I follow "Dashboard"
    Then I should not see a purchase named "Jacket"
    And the "Money at risk" stat should show "$0.00"

  Scenario: Full return walkthrough with quick buttons
    Given I am on the Dashboard
    When I press "Return it" on the "Jacket" card
    And I press "Sent it back" on the "Jacket" card
    Then purchase "Jacket" should show status "Shipped back"
    And the "Jacket" card should show "Shipped back on" with the date "2026-10-15"
    When I press "Refund received" on the "Jacket" card
    Then I should be on History
    And purchase "Jacket" should show status "Refunded"
    And the "Jacket" card should show "Refunded on" with the date "2026-10-15"

  Scenario: Skip straight to refunded with the dropdown (in-store return)
    Given I am on the Dashboard
    When I quickly update purchase "Jacket" to status "Refunded"
    Then I should be on History
    And purchase "Jacket" should show status "Refunded"

  Scenario: Can't reopen a purchase whose deadline has passed by status alone
    Given I have the following purchases:
      | item  | return_by  |
      | Mixer | 2026-10-10 |
    And I am on History
    Then purchase "Mixer" should show status "Expired"
    And the "Mixer" card should only offer ""
    When I quickly update purchase "Mixer" to status "Returning"
    Then I should see "The return-by date has passed. Edit the return-by date to reopen this purchase." in the main content
    And purchase "Mixer" should show status "Expired"
    When I quickly update purchase "Mixer" to status "Active"
    Then I should see "The return-by date has passed. Edit the return-by date to reopen this purchase." in the main content
    And purchase "Mixer" should show status "Expired"

  Scenario: The edit form can't reopen an expired purchase by status alone either
    Given I have the following purchases:
      | item  | return_by  |
      | Mixer | 2026-10-10 |
    And I am on History
    When I press "Edit" on the "Mixer" card
    And I select "Returning" from "Status"
    And I press "Save Purchase"
    Then I should see "The return-by date has passed. Edit the return-by date to reopen this purchase." in the main content

  Scenario: Fixing other details of an expired purchase keeps it expired
    Given I have the following purchases:
      | item  | price | return_by  |
      | Mixer | 80.00 | 2026-10-10 |
    And I am on History
    When I press "Edit" on the "Mixer" card
    And I fill in "Price" with "75.00"
    And I press "Save Purchase"
    Then I should be on History
    And purchase "Mixer" should show status "Expired"
    And the "Mixer" card should show "$75.00"

  Scenario: Extending the deadline brings an expired purchase back
    Given I have the following purchases:
      | item  | return_by  |
      | Mixer | 2026-10-10 |
    And I am on History
    When I press "Edit" on the "Mixer" card
    And I fill in "Return By" with "2026-10-25"
    And I press "Save Purchase"
    Then I should be on the Dashboard
    And purchase "Mixer" should show status "Active"
    And the "Mixer" card should show "10 days left"

  Scenario Outline: An expired purchase can still be settled
    Given I have the following purchases:
      | item  | return_by  |
      | Mixer | 2026-10-10 |
    And I am on History
    When I quickly update purchase "Mixer" to status "<status>"
    Then I should be on <page>
    And purchase "Mixer" should show status "<status>"

    Examples:
      | status         | page      |
      | Keeping        | History   |
      | Shipped back   | Dashboard |
      | Refund pending | Dashboard |
      | Refunded       | History   |

  Scenario Outline: Open purchases expire the day after the deadline
    Given I have the following purchases:
      | item  | price | return_by  | status   |
      | Dress | 45.00 | 2026-10-31 | <status> |
    And today is <today>
    When I go to <page>
    Then purchase "Dress" should show status "<result>"

    Examples:
      | status         | today      | page      | result         |
      | Active         | 2026-10-31 | Dashboard | Active         |
      | Active         | 2026-11-01 | History   | Expired        |
      | Returning      | 2026-10-31 | Dashboard | Returning      |
      | Returning      | 2026-11-01 | History   | Expired        |
      | Keeping        | 2026-11-01 | History   | Keeping        |
      | Shipped back   | 2026-11-01 | Dashboard | Shipped back   |
      | Refund pending | 2026-11-01 | Dashboard | Refund pending |
