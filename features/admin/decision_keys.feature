Feature: Admin decision keys
  Clicking a decision's key copies it.

  Background:
    Given I am signed in to the admin
    And a decision "Pick a queue" with the problem "Jobs pile up"

  Scenario: Clicking the key in the list copies it
    When I visit "/admin/decisions"
    And I watch the decisions clipboard
    And I click the decision key in ".decision-row:has-text('Pick a queue')"
    Then I see "Decision #1 copied"
    And the decisions clipboard holds "#1"

  Scenario: Clicking the key on the decision page copies it
    When I visit "/admin/decisions/1"
    And I watch the decisions clipboard
    And I click the decision key in ".read-meta"
    Then I see "Decision #1 copied"
    And the decisions clipboard holds "#1"
